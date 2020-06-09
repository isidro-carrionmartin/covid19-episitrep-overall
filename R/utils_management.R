

# Set the term of dates this is also used to separate output files
set_date_max <- function(date_max, get_updated_data = FALSE){
  
  get_updated_data <- get_updated_data
  
  date_max <- as.Date(date_max)

  # Create folders speficit to date_max
  path.local.day    <- file.path(path.local, date_max)
  path.local.data   <- file.path(path.local.day, 'data')
  path.local.graphs <- file.path(path.local.day, 'graphs')
  path.local.tables <- file.path(path.local.day, 'tables')

  dir.create(path.local.day    , showWarnings = FALSE, recursive = TRUE) 
  dir.create(path.local.data   , showWarnings = FALSE, recursive = TRUE) 
  dir.create(path.local.graphs , showWarnings = FALSE, recursive = TRUE) 
  dir.create(path.local.tables , showWarnings = FALSE, recursive = TRUE) 
  
  return((date_max))

}

# Formatting Confidence Intervals


combine_ci <- function(lwr, upr, digits = 1) {
  sprintf(glue("[%.{digits}f - %.{digits}f]"), 
        round(lwr, digits = digits),
        round(upr, digits = digits))
}


format_ci <- function(tbl) {
  tbl <- tbl %>% mutate(
    l_cnt_ci = case_when(
      !is.na(l_cnt_est) ~ combine_ci(l_cnt_lwr, l_cnt_upr), 
      TRUE ~NA_character_), 
    p_cnt_ci = case_when(
      !is.na(p_cnt_est) ~ combine_ci(p_cnt_lwr, p_cnt_upr), 
      TRUE ~NA_character_), 
    l_cml_ci = case_when(
      !is.na(l_cml_est) ~ combine_ci(l_cml_lwr, l_cml_upr), 
      TRUE ~NA_character_), 
    p_cml_ci = case_when(
      !is.na(p_cml_est) ~ combine_ci(p_cml_lwr, p_cml_upr), 
      TRUE ~NA_character_), 
    l_cnt_est = round(l_cnt_est, digits = 1), 
    p_cnt_est = round(p_cnt_est, digits = 1), 
    p_cml_est = round(p_cml_est, digits = 1), 
    l_cml_est = round(l_cml_est, digits = 1))
  
  return(tbl)
}



vars_trends <- function(model){
  
  stub_vars <- c('coeff', 'lwr', 'upr')
  
  lst_vars <- switch(model, 
                     linear       = c(paste0('l_cnt_', stub_vars), 'trend_linear'), 
                     quasipoisson = c(paste0('p_cnt_', stub_vars), 'trend_quasipoisson'))
  
  names(lst_vars) <- c(stub_vars, 'trend')
  
  return(lst_vars)
  
}


vars_doubling_time <- function(model, series){
  
  stub_vars <- c('est', 'lwr', 'upr')
  
  lst_vars <- switch(model, 
                     linear       = paste0('l_cml_', stub_vars), 
                     quasipoisson = paste0('p_cml_', stub_vars))
  
  names(lst_vars) <- switch(series, 
                     cases  = paste0('cases_' , stub_vars), 
                     deaths = paste0('deaths_', stub_vars))
  
  return(lst_vars)
  
}



attach_prefix <- function(var_in, suffix_var_out) {
  setNames(as.vector(var_in), paste0(suffix_var_out, var_in))
}



prepare_msf_dta <- function(dta){
  
  # Rename variables
  var_names_stub <- c('^patinfo_', '^patcourse_', '^MSF_', '_patcourse')
  
  for (i in var_names_stub) {
    names(dta) <- gsub(i, '', names(dta))
  }
  
  
  # Factorise variables
  levels_covid_status <- c('Confirmed', 'Probable', 'Suspected', 'Not a case', '(Unknown)')
  
  levels_outcome_status <- c('Died', 'Cured', 'Left against medical advice' ,'Transferred', 'Sent back home', 'Other')
  
  levels_ynu <- c('Yes', 'No', 'Unknown')
  
  dta <- dta %>% 
    mutate(
      covid_status = factor(covid_status, levels = levels_covid_status) %>% forcats::fct_explicit_na(na_level = '(Unknown)'), 
      country = factor(country, levels = df_countries$iso_a3, labels = df_countries$country), 
      age_in_years = floor(age_in_years), 
      admit = factor(admit, levels = levels_ynu) %>% forcats::fct_explicit_na(na_level = 'Unknown'), 
      outcome_admit = factor(outcome_admit, levels = levels_ynu) %>% forcats::fct_explicit_na(na_level = 'Unknown'), 
      outcome_status = factor(outcome_status, levels = levels_outcome_status) %>% forcats::fct_explicit_na(na_level = 'Pending/Unknown')
    )
  
  return(dta)
}


