# Tables, correlation heatmaps and maps, in the style of the original notebooks.

library(knitr)
library(kableExtra)
library(corrplot)

# Min/quartiles/mean/max per variable, written as a striped HTML table.
# `variables` may be named (names become the row labels). Variables missing from `data`
# stay NA, as in the original loops. Source: notebooks/02, "Summary Table" chunks.
summary_table <- function(data, variables) {
  labels <- if (is.null(names(variables))) variables else names(variables)
  summary_data <- data.frame(
    Variable = labels,
    Min = NA,
    First_Qu = NA,
    Median = NA,
    Mean = NA,
    Third_Qu = NA,
    Max = NA
  )
  for (i in seq_along(variables)) {
    desc_name <- labels[[i]]
    var <- variables[[i]]
    if (var %in% colnames(data)) {
      summary_values <- summary(data[[var]])
      summary_data[summary_data$Variable == desc_name, "Min"] <- summary_values["Min."]
      summary_data[summary_data$Variable == desc_name, "First_Qu"] <- summary_values["1st Qu."]
      summary_data[summary_data$Variable == desc_name, "Median"] <- summary_values["Median"]
      summary_data[summary_data$Variable == desc_name, "Mean"] <- summary_values["Mean"]
      summary_data[summary_data$Variable == desc_name, "Third_Qu"] <- summary_values["3rd Qu."]
      summary_data[summary_data$Variable == desc_name, "Max"] <- summary_values["Max."]
    }
  }
  colnames(summary_data) <- c("Variable", "Min", "1st Qu", "Median", "Mean", "3rd Qu", "Max")
  summary_data
}

save_html_table <- function(df, file) {
  table_html <- kable(df, format = "html") %>%
    kable_styling(bootstrap_options = "striped", full_width = F)
  save_kable(table_html, file)
}

# ---- Correlation heatmaps (notebooks/02) -----------------------------------------------

# Masks applied before plotting; `fill` is 0 (blank circle) or NA (hidden cell).
keep_at_least <- function(t, fill = 0) function(m) { m[m < t] <- fill; m }
keep_abs_at_least <- function(t, fill = 0) function(m) { m[m < t & m > -t] <- fill; m }
keep_at_most <- function(t, fill = 0) function(m) { m[m > t] <- fill; m }

# corrplot argument sets shared by the original blocks.
style_full <- function(tl.cex, bounded) {
  args <- list(method = "circle", type = "lower",
               col = colorRampPalette(c("red", "white", "purple"))(200),
               tl.col = "black", tl.cex = tl.cex, tl.srt = 45, cl.cex = 0.8,
               addgrid.col = "grey")
  # "bounded" plots draw the full matrix on a fixed 0..1 legend, as the original did for
  # sound-only matrices (is.corr = FALSE, cl.lim = c(0, 1)).
  if (bounded) c(args, list(cl.lim = c(0, 1), is.corr = FALSE)) else c(args, list(is.corr = TRUE))
}
style_highlight <- function(colors, tl.cex) {
  list(method = "circle", type = "lower", col = colorRampPalette(colors)(200),
       tl.col = "black", tl.cex = tl.cex, tl.srt = 45, cl.cex = 0.8, cl.lim = c(0, 1),
       na.label = " ", addgrid.col = "grey", is.corr = FALSE)
}
style_coefficients <- list(
  type = "lower", col = colorRampPalette(c("white", "white"))(200), cl.pos = "n",
  tl.col = "black", tl.cex = 1, tl.srt = 45, cl.cex = 0.8, cl.lim = c(0, 1),
  na.label = " ", addgrid.col = "grey", is.corr = FALSE,
  addCoef.col = "black", number.cex = 1, number.digits = 2
)

# Draw one heatmap to `file`: mask the matrix, corrplot() with `style`, then a base title.
# `title_cex = NULL` leaves cex.main at the graphics default, like title() calls without it.
plot_cor_heatmap <- function(cor_matrix, file, style, title, mask = identity,
                             title_line = 3, title_cex = NULL, size = 800) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  png(file, width = size, height = size)
  on.exit(dev.off())
  do.call(corrplot, c(list(mask(cor_matrix)), style))
  if (is.null(title_cex)) {
    title(title, line = title_line)
  } else {
    title(title, cex.main = title_cex, line = title_line)
  }
  invisible(file)
}

# ---- Leaflet maps (archive/private/03 and notebooks/04) --------------------------------

library(leaflet)

map_flares_wells_buffer <- function(b) {
  leaflet() %>%
    addTiles() %>%
    # Add buffer (20 km around central point)
    addPolygons(data = b$buffer_20km_wgs84, color = "blue", fillOpacity = 0.2,
                popup = "20 km Buffer") %>%
    addMarkers(data = b$central_point_wgs84, popup = "Central Point (The Trailer)", label = "The Trailer") %>%
    addCircleMarkers(data = b$flare_points_in_buffer20, color = "green", radius = 3,
                     label = ~"Flares within 20km buffer") %>%
    addCircleMarkers(data = b$wells_in_buffer20, color = "green", radius = 3,
                     label = ~"Wells within 20km buffer") %>%
    addCircleMarkers(data = b$flare_points_outside_buffer, color = "orange", radius = 3,
                     label = ~"Flares outside 20km buffer") %>%
    addCircleMarkers(data = b$wells_outside_buffer, color = "orange", radius = 3,
                     label = ~"Wells outside 20km buffer") %>%
    addLegend("bottomright", colors = c("green", "orange"), labels = c("Inside Buffer", "Outside Buffer"),
              title = "Flares & Wells Location")
}

# Point-density heat map (wells or flares) with the trailer marked.
map_density <- function(points) {
  leaflet(points) %>%
    addTiles() %>%
    leaflet.extras::addHeatmap(lng = ~lon, lat = ~lat, intensity = 1, blur = 20, max = 0.05, radius = 15) %>%
    addMarkers(data = st_transform(central_point, crs = 4326), popup = "Central Point (The Trailer)", label = "The Trailer") %>%
    addLegend("bottomright", colors = c("blue", "red"), labels = c("Low", "High"),
              title = "Density")
}

save_map <- function(map, file) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  htmlwidgets::saveWidget(map, normalizePath(file, mustWork = FALSE), selfcontained = TRUE)
}
