#######################################
## Title: Employment global.R            ##
## Author(s): Emily Ramos, Arvind    ##
##            Ramakrishnan, Jenna    ##
##            Kiridly, Steve Lauer   ## 
## Date Created:  1/5/2015          ##
## Date Modified: 1/7/2015          ##
#######################################

##First file run - Environment Setup
## load necessary libraries
require(dplyr)
require(sp)
require(maptools)
require(rgeos)
require(Hmisc)
require(reshape2)
require(shiny)
require(googleCharts)
require(leaflet)
require(RJSONIO)
require(rCharts)
require(tidyr)

## load map data
##County is not necessary for this app
MA_map_county <- fromJSON("County_2010Census_DP1.geojson")
MA_map_muni <- fromJSON("Muni_2010Census_DP1.geojson")

## Load formatted Income status data
## -1 eliminates first column [rows,columns]
emp_data <- read.csv(file="employmentdata2.csv")[,-1]

## Find order of counties in geojson files
## Each county is a separate feature
## No county data
# 
# MA_counties <- c()
# for(i in 1:length(MA_map_county$features)){
#   MA_counties <- c(MA_counties, MA_map_county$features[[i]]$properties$County)
# }

## Find order of municipals in geojson files
## Each municipal is a separate feature
for(i in 1:length(MA_map_muni$features)){
  MA_map_muni$features[[i]]$properties$NAMELSAD10 <- substr(MA_map_muni$features[[i]]$properties$NAMELSAD10, 1, nchar(MA_map_muni$features[[i]]$properties$NAMELSAD10)-5)
}

MA_municipals_map <- c()
for(i in 1:length(MA_map_muni$features)){
  MA_municipals_map <- c(MA_municipals_map, MA_map_muni$features[[i]]$properties$NAMELSAD10)
}

idx_leftovers <- which(!MA_municipals_map %in% emp_data$Region)
leftover_munis <- MA_municipals_map[idx_leftovers]
for(i in 1:length(leftover_munis)){
 MA_map_muni$features[[idx_leftovers[i]]]$properties$NAMELSAD10 <- 
  substr(leftover_munis[i], 1, nchar(leftover_munis[i])-5)
}

MA_municipals <- c()
for(i in 1:length(MA_map_muni$features)){
 MA_municipals <- c(MA_municipals, MA_map_muni$features[[i]]$properties$NAMELSAD10)
}
idx_leftovers2 <- which(!MA_municipals %in% emp_data$Region)
leftover_munis_map <- MA_municipals[idx_leftovers2]
MA_municipals <- sort(MA_municipals[-idx_leftovers2])

## Set graph colors (special for colorblind people)
## In order: black, orange, light blue, green, yellow, dark blue, red, pink
cbbPalette <- c("#000000", "#E69F00", "#56B4E9", "#009E73", "#F0E442", 
                "#0072B2", "#D55E00", "#CC79A7")

## Create maxs and mins for googleCharts/Plot tab
xlim <- list(
  min = min(emp_data$Year)-1,
  max = max(emp_data$Year)+1
)
ylim <- list(
  min = 0,
  max = max(emp_data$Average_Monthly_Employment)
)

## Colors for a single-year legend
paint_brush <- colorRampPalette(colors=c("white", "red3"))
map_colors <- c(paint_brush(n=5), "#999999")

##Cuts are quintiles of the total data
## Cuts based on entire dataset - not year specific - This keeps colors consistent for maps year-to-year

max_val <- max(emp_data$Average_Monthly_Employment)
min_val <- 0

## Puts each county year in between the cuts (n colors, n+1 cuts)
## length.out will make that many cuts
cuts <- seq(min_val, max_val, length.out = length(map_colors))

## Construct break ranges for displaying in the legend
## Creates a data frame
## head = scuts takes everything except for the last one, 
## tails = same thing opposite

colorRanges <- data.frame(
  from = head(cuts, length(cuts)-1),
  to = tail(cuts, length(cuts)-1)
)


#############################
### Large Text Block Area ###
#############################

## Generate map button
gen_map_button <- HTML('<style type="text/css">
       .action-button {
       -moz-box-shadow:inset 0px 1px 0px 0px #54a3f7;
                       -webkit-box-shadow:inset 0px 1px 0px 0px #54a3f7;
                       box-shadow:inset 0px 1px 0px 0px #54a3f7;
                       background:-webkit-gradient(linear, left top, left bottom, color-stop(0.05, #007dc1), color-stop(1, #0061a7));
                       background:-moz-linear-gradient(top, #007dc1 5%, #0061a7 100%);
                       background:-webkit-linear-gradient(top, #007dc1 5%, #0061a7 100%);
                       background:-o-linear-gradient(top, #007dc1 5%, #0061a7 100%);
                       background:-ms-linear-gradient(top, #007dc1 5%, #0061a7 100%);
                       background:linear-gradient(to bottom, #007dc1 5%, #0061a7 100%);
                       filter:progid:DXImageTransform.Microsoft.gradient(startColorstr="#007dc1", endColorstr="#0061a7",GradientType=0);
                       background-color:#007dc1;
                       -moz-border-radius:3px;
                       -webkit-border-radius:3px;
                       border-radius:3px;
                       border:1px solid #124d77;
                       display:inline-block;
                       cursor:pointer;
                       color:#ffffff;
                       font-family:arial;
                       font-size:16px;
                       padding:12px 36px;
                       text-decoration:none;
                       text-shadow:0px 1px 0px #154682;
                       }
                       .action-button:hover {
                       background:-webkit-gradient(linear, left top, left bottom, color-stop(0.05, #0061a7), color-stop(1, #007dc1));
                       background:-moz-linear-gradient(top, #0061a7 5%, #007dc1 100%);
                       background:-webkit-linear-gradient(top, #0061a7 5%, #007dc1 100%);
                       background:-o-linear-gradient(top, #0061a7 5%, #007dc1 100%);
                       background:-ms-linear-gradient(top, #0061a7 5%, #007dc1 100%);
                       background:linear-gradient(to bottom, #0061a7 5%, #007dc1 100%);
                       filter:progid:DXImageTransform.Microsoft.gradient(startColorstr="#0061a7", endColorstr="#007dc1",GradientType=0);
                       background-color:#0061a7;
                       }
                       .action-button:active {
                       position:relative;
                       top:1px;
                       }
                       
                       </style>')

summary_side_text <- conditionalPanel(
  condition="input.tabs == 'summary'",
  ## h4 created 4th largest header
  h4("How to use this app:"),
  ## Creates text
  helpText(p(strong('Please select the year or range for which you are interested in viewing average annual employment rates.'))),
  tags$br(),
  tags$ul(
#       tags$li('View rates by: male or female (or both by leaving this selection blank)'),
#       tags$br(),
      tags$li('Select one or multiple municipalities.'),
      tags$br()
      # tags$li('To compare median data to the Massachusetts median or US median, select the corresponding check box'),
      # tags$br(),
      # tags$li(p(strong('Please note that all statistics are 5-year medians')))
            
  )
)
  
  
  ## Creates horizontal line
  ##tags$hr()


## Same concept
plot_side_text <- conditionalPanel(
  condition="input.tabs == 'plot'",
  h4("How to use this app:"),
p(strong('Please select a municipality to analyze average monthly employment by municipatlity.')),
           tags$br(),
  tags$ul(
    tags$li('On a yearly basis, compare the average monthly employment numbers across municipalities .')
    ))

map_side_text <- conditionalPanel(
  condition="input.tabs == 'map'",
  h4("How to use this app:"),

  helpText(p(strong('Please click on "Generate Map" to get started'))),
  tags$br(),
  tags$ul(
    tags$li('Clicking on a municipality will display the average monthly employment figures for the selected year.')
    ))

info_side_text <- conditionalPanel(
  condition="input.tabs == 'info'",
  h4("How to use this app:"),
  helpText(p(strong('This tab contains more detailed information regarding the variables of interest.___Maybe not necessary?'))))
 


about_main_text <- p(strong("The SEIGMA Income Status App"), "displays the yearly average monthly employment figures for Massachusetts by municipality. Toggle between tabs to visualize the data differently.",
    tags$br(),
    tags$ul(
      tags$li(p(strong("Summary"), "shows source data in tabular format.")),
      tags$li(p(strong("Plot"), "compares any municipality's average to county, state, and national medians._only municipality currently available")),
      tags$li(p(strong("Map"), "visually displays average monthly employment figures comparatively by municipality")),
      tags$li(p(strong("More Info"), "lists descriptions for the variables of interest, including, formulae and calculations"))
  )
)


plot_main_text <- p(strong("Variable Summary:"),
                    ## breaks between paragraphs
                    tags$br(),
                    p(strong("Average Monthly Employment"),
                    " - Average monthly employment statistics on a year-to-year basis for each municipality."))

font_size <- 14