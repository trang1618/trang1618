## ---------------------------------------------------------
library(rorcid)
library(rcrossref)
library(dplyr)
library(purrr)
library(janitor)
library(here)
library(yaml)
library(jsonlite)
library(humaniformat)
library(snakecase)


## ----------------------------------------------------------
my_orcid <- '0000-0003-3737-6565'
cites <- orcid_citations(my_orcid, cr_format = "citeproc-json")
jobs <- orcid_employments(my_orcid)[[my_orcid]]
edu <- orcid_educations(my_orcid)

set_class <- function(x, new_class) {
  class(x) <- new_class
  x
}

## ------------------------------------------------------------------------
cites2 <- cites %>%
  dplyr::distinct(ids, .keep_all = TRUE) %>%
  mutate(citation = purrr::map(citation, jsonlite::fromJSON))
purrr::map(cites$citation, jsonlite::fromJSON)
condense_author <- function(x) {
  full_aut <- as.list(paste(x$author$given, x$author$family))
  if (length(full_aut) > 15) {
    authors <-
      list(full_aut[[1]], '...', 'Trang T Le', '...', tail(full_aut, 1)[[1]])
  } else {
    authors <- full_aut
  }
  authors
}
publist <-
  purrr::map(cites2$citation, function(x) {
    date <-
      list(
        name = gsub('\\<a\\>|\\<the\\>', '', x$title, ignore.case = T) %>%
          gsub("([A-Za-z]+).*", "\\1", .) %>%
          tolower() %>%
          paste0("_", x$created$`date-parts`[1]),
        doi = x$DOI,
        preprint = (x$institution$name == 'bioRxiv'),
        type = "paper",
        title = x$title,
        authors = condense_author(x),
        date = as.character(as.Date(
          paste(x$created$`date-parts`, collapse = "-")
        )),
        exurl = paste0("https://dx.doi.org/", x$DOI)
      )
  })
names(publist) <- map_chr(publist, "name")
write_yaml(publist, here("data", "papers_orcid.yaml"))
publist_manual <- yaml::read_yaml(here("data", "papers_manual.yaml"))
publist <-
  c(publist, publist_manual[!(names(publist_manual) %in% names(publist))])
for (pubname in names(publist_manual)) {
  if (pubname %in% names(publist)) {
    for (field in names(publist_manual[[pubname]])) {
      publist[[pubname]][[field]] <- publist_manual[[pubname]][[field]]
    }
  }
}
write_yaml(publist, here("data", "papers.yaml"))


joblist <-
  purrr::map(jobs[["affiliation-group"]][["summaries"]], function(x) {
    list(
      name = paste0(to_snake_case(paste(x[["employment-summary.organization.name"]], x[["employment-summary.start-date.year.value"]]))),
      title = x[["employment-summary.role-title"]],
      organization = x[["employment-summary.organization.name"]],
      location  = paste0(x[["employment-summary.organization.address.city"]], ", ", x[["employment-summary.organization.address.region"]]),
      start_date = as.Date(paste(x[["employment-summary.start-date.year.value"]],
                                 x[["employment-summary.start-date.month.value"]],
                                 x[["employment-summary.start-date.day.value"]],
                                 sep = "-")),
      end_date = as.Date(paste(x[["employment-summary.end-date.year.value"]],
                               x[["employment-summary.end-date.month.value"]],
                               x[["employment-summary.end-date.day.value"]],
                               sep = "-"))
    )
  })
names(joblist) <- map_chr(joblist, "name")
write_yaml(joblist,
           here("data", "employment.yaml"),
           handlers = list(
             Date = function(x)
               as.character (x)
           ))

edulist <-
  purrr::map(edu[[my_orcid]][["affiliation-group"]][["summaries"]], function(x) {
    list(
      name = paste0(to_snake_case(paste(x[["education-summary.role-title"]],
                                        x[["education-summary.department-name"]],
                                        x[["education-summary.end-date.year.value"]]))),
      type = "degree",
      title = x[["education-summary.role-title"]],
      university = x[["education-summary.organization.name"]],
      department = x[["education-summary.department-name"]],
      location  = paste0(x[["education-summary.organization.address.city"]], ", ", x[["education-summary.organization.address.region"]]),
      date = as.Date(paste(x[["education-summary.end-date.year.value"]],
                           x[["education-summary.end-date.month.value"]],
                           x[["education-summary.end-date.day.value"]],
                           sep = "-"))
    )
  })
names(edulist) <- map_chr(edulist, "name")
write_yaml(edulist,
           here("data", "education.yaml"),
           handlers = list(
             Date = function(x)
               as.character (x)
           ))

