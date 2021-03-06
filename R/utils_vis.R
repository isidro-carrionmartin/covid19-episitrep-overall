
# set ggplot theme
ggplot2::theme_set(ggplot2::theme_bw())


cm_to_in <- 0.39370079



add_brks <- function(x, n = 5, style = "jenks") {
  breaks <- classInt::classIntervals(x, n = n, style = style)
  br <- breaks$brks
  cut(x, br, include.lowest = TRUE, labels = label_breaks(br))
}



label_breaks <- function(breaks, type = "integer") {
  x <- breaks[1:length(breaks) - 1]
  y <- breaks[2:length(breaks)]
  paste(frmt_num(x), frmt_num(y), sep = "-")
}




frmt_num <- function(x) {
  scales::label_number_si()(x)
}



freq_prct <- function(x, value){
  paste0(sum(x == value, na.rm = TRUE), 
         ' (', 
         format(round(sum(x == value, na.rm = TRUE) / sum(!is.na(x)) * 100, digits = 1), nsmall = 1), 
         ')')
}



call_countries_with_more <- function(dta, limit, series){
  
  series <- sym(series)
  
  dta %>% 
    filter(!!series > limit) %>% 
    arrange(desc(!!series)) %>% 
    pull(country)
}



call_countries_with_less <- function(dta, limit, series){
  
  series <- sym(series)
  
  dta %>% 
    filter(!!series < limit) %>% 
    arrange(desc(!!series)) %>%  
    pull(country)
}



call_countries_increasing <- function(obs, continent_name = NULL){
  
  selected_tbl <- switch(obs, 
                         cases  = tbl_cases_increasing_trend, 
                         deaths = tbl_deaths_increasing_trend)
  
  if (!is.null(continent_name)) {
    selected_tbl <- filter(selected_tbl, continent %in% continent_name)
  }
  
  selected_tbl <- arrange(selected_tbl, desc(coeff))
  
  called_countries <- pull(selected_tbl, 'country')
  
  return(called_countries)
  
}



call_countries_doubling <- function(est, continent_name = NULL){
  
  est <- sym(est)
  
  if (!is.null(continent_name)) {
    selected_tbl <- filter(tbl_cfr_doubling_rank, continent %in% continent_name)
  } else {
    selected_tbl <- tbl_cfr_doubling_rank
  }
  
  selected_tbl <- filter(selected_tbl, !!est < threshold_doubling_time)
  selected_tbl <- arrange(selected_tbl, desc(!!est))
  
  called_countries <- pull(selected_tbl, 'country')
  
  return(called_countries)
  
}



country_plot <- function(country_iso, series, lst_dta = lst_ecdc, model = 'linear', date_min = NULL) {
  
  choice <- paste(series, model, sep = '_')
  
  mld_list <- switch(choice, 
                     cases_linear   = model_cnt_cases_linear, 
                     deaths_linear  = model_cnt_deaths_linear, 
                     cases_poisson  = model_cnt_cases_poisson, 
                     deaths_poisson = model_cnt_deaths_poisson)

  mld_par <- mld_list[[5]]
  dates_extent <- c(mld_par[[1]][1], mld_par[[1]][2])
  
  mdl <- mld_list[[2]][[country_iso]]
  
  dta_obs <- lst_dta[[country_iso]] %>% 
    select(date, obs = all_of(series))
  
  dta_mdl <- tibble(dta_obs %>% 
                          filter(between(date, 
                                         left = dates_extent[1],  
                                         right = dates_extent[2])), 
                        fit = mdl$fit, 
                        lwr = mdl$lwr, 
                        upr = mdl$upr)
  
  obs_max <- max(dta_obs$obs, na.rm = TRUE)
  
  if (is.null(date_min)) {
    date_min <- dta_obs %>% filter(obs != 0) %>% pull(date) %>% min()
  }
  
  main_colour <- switch(series, 
                        cases  = '#1A62A3',
                        deaths = '#e10000')
  
  # The complete epicurve
  plot_obs <- ggplot(dta_obs, aes(x = date, y = obs)) + 
    geom_col(colour = main_colour, fill = main_colour) + 
    scale_x_date(limits = c(date_min, NA)) + 
    xlab('') + 
    ylab(series) + 
    labs(subtitle = 'Since the first cases reported') + 
    theme_light()
  
  # The model
  plot_mdl <- ggplot(dta_mdl, aes(x = date, y = obs)) + 
    geom_point(size = 2 , colour = main_colour) + 
    geom_line(aes(y = fit), colour = main_colour, size = 1) + 
    geom_ribbon(aes(ymin = lwr, ymax = upr), fill = main_colour, alpha = 0.4) + 
    xlab('') + 
    ylab(paste0(series, '/ fitted values')) + 
    labs(subtitle = paste('Last', length(dta_mdl$obs), 'days')) + 
    theme_light() 
  
  # List the plots
  return(list(plot_obs, plot_mdl, model = model))
  
}



# Plot cases or deaths for a single country with a zoom in the last 12 days -->
country_duo_plots <- function(series, country_iso, lst_dta = lst_ecdc, model = 'linear') {
  
  name_country <- df_countries %>% filter(iso_a3 == country_iso) %>% pull(country)
  
  grid.arrange(country_plot(country_iso = country_iso, series = series, model = model)[[1]], 
               country_plot(country_iso = country_iso, series = series, model = model)[[2]],
             ncol = 2, 
             top = textGrob(paste(glue('Covid-19 cases and deaths and trend estimations in {name_country}'), 
                                  glue('Data until {format(date_max_report, "%d %B %Y")}'), 
                                  sep = "\n"), 
                            gp = gpar(fontface = 'bold')))
}



# To to plot both cases and deaths into a single graphic plot
country_multi_plots <- function(country_iso, lst_dta = lst_ecdc, model = 'linear') {
  
  # Parameters
  main_colour  <- c(cases = '#1A62A3', deaths = '#e10000')
  name_country <- df_countries %>% filter(iso_a3 == country_iso) %>% pull(country)
  date_min     <- lst_dta[[country_iso]] %>% filter(cases != 0) %>% pull(date) %>% min()
  
  # Table observations
  dta_obs <- lst_dta[[country_iso]] %>% 
    select(date, cases, deaths) %>% 
    pivot_longer(-date, names_to = 'obs', values_to = 'count')
  
  
  # Table predictions
  lst_cases_mdl <- switch(model, 
                          linear  = model_cnt_cases_linear, 
                          poisson = model_cnt_cases_poisson)
  
  
  lst_deaths_mdl <- switch(model, 
                           linear  = model_cnt_deaths_linear, 
                           poisson = model_cnt_deaths_poisson)
  
  mld_par <- lst_cases_mdl[[5]]
  dates_extent <- c(mld_par[[1]][1], mld_par[[1]][2])
  
  dta_cases_mod <- lst_dta[[country_iso]] %>% 
    select(date, count = cases) %>% 
    mutate(
      obs = 'cases') %>% 
    filter(between(date, dates_extent[1], dates_extent[2])) %>% 
    tibble::add_column(lst_cases_mdl[['preds']][[country_iso]])
  
  dta_deaths_mod <- lst_dta[[country_iso]] %>% 
    select(date, count = deaths) %>% 
    mutate(
      obs = 'deaths') %>% 
    filter(between(date, dates_extent[1], dates_extent[2])) %>% 
    tibble::add_column(lst_deaths_mdl[['preds']][[country_iso]]) # This should be 11 rows
  
  dta_mod <- rbind(dta_cases_mod, dta_deaths_mod)
  
  
  # Plots
  plot_obs <- ggplot(dta_obs, aes(x = date, y = count)) + 
    facet_wrap(~obs, scales = "free_y", ncol = 1) + 
    geom_col(aes(colour = obs, fill = obs)) + 
    scale_colour_manual(values = main_colour) + 
    scale_fill_manual(values = main_colour) + 
    scale_x_date(limits = c(date_min, NA), date_labels = "%b-%Y") +
    xlab('') + 
    ylab('frequency') + 
    labs(subtitle = 'Since the first cases reported') + 
    theme_light() + 
    theme(legend.position = "none", 
          strip.text = element_text(size = 11))
  
  
  plot_mod <- ggplot(dta_mod, aes(x = date, y = count)) + 
    facet_wrap(~ obs, scales = "free_y", ncol = 1) + 
    geom_point(aes(colour = obs), size = 2) + 
    scale_colour_manual(values = main_colour) + 
    geom_ribbon(aes(ymin = lwr, ymax = upr, fill = obs), alpha = 0.4) + 
    geom_line(aes(y = fit, colour = obs), size = 1) + 
    scale_fill_manual(values = main_colour) + 
    scale_x_date(limits = c(dates_extent[[1]], dates_extent[[2]]), date_labels = "%d-%b") +
    xlab('') + 
    ylab(paste0('frequency and fitted values')) + 
    labs(subtitle = paste('Last', length(dta_cases_mod$obs), 'days')) + 
    theme_light() + 
    theme_light() + 
    theme(legend.position = "none", 
          strip.text = element_text(size = 11))
  
  grid.arrange(plot_obs, 
               plot_mod, 
               ncol = 2, 
               top = textGrob(paste(glue('Covid-19 cases and deaths and trend estimations in {name_country}'), 
                                    glue('Data until {format(date_max_report, "%d %B %Y")} (fitting with {model} regression model)'), 
                                    sep = "\n"), 
                              gp = gpar(fontface = 'bold')))
}



country_plot_coeff <- function(series, country_iso) {
  
  name_country <- df_countries %>% filter(iso_a3 == country_iso) %>% pull(country)
  
  df_country <- switch(series, 
                       cases  = lst_coeffs_cases[[country_iso]], 
                       deaths = lst_coeffs_deaths[[country_iso]])
  
  quo_series <- sym(series)
  
  main_colour <- switch(series, 
                        cases  = '#1A62A3',
                        deaths = '#e10000')
  
  date_min <- min(df_country$date, na.rm = TRUE)
  date_max <- max(df_country$date, na.rm = TRUE)
  
  plot_crv <- ggplot(df_country, aes(x = date, y = !!quo_series)) + 
    geom_col(colour = main_colour,  fill = main_colour) + 
    xlim(c(date_min, date_max)) + 
    xlab('') + 
    ylab(series) + 
    labs(subtitle = glue('Number of {series} reported')) + 
    theme_light()
  
  plot_cff <- ggplot(df_country, aes(x = date)) +
    geom_line(aes(y = coeff), colour = '#1B9E77', size = 1) + 
    geom_ribbon(aes(ymin = lwr, ymax = upr), fill = '#1B9E77', alpha = 0.4) + 
    xlim(c(date_min, date_max)) + 
    #scale_x_date(date_breaks = "4 weeks", date_labels = "%d %b") + 
    xlab(NULL) + 
    ylab('Slope coefficient') + 
    labs(subtitle = 'Slope coefficient curve') + 
    theme_light()
  
  grid_plot <- grid.arrange(rbind(ggplotGrob(plot_crv), ggplotGrob(plot_cff)), 
                               top = textGrob(glue('Evolution of the slope cofficient in {name_country}'), 
                                              gp = gpar(fontface = 'bold')))
  
  return(grid_plot)
  
}
