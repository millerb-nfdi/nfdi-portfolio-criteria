library(dplyr)
library(tidyr)
library(purrr)
library(stringr)
library(readxl)
library(lubridate)


# Script to read in consortia evaluations of the NFDI portfolio criteria.
# Expects one Excel-File per service (filename structure see below)
# Expects criteria-hierarchy as in document subnitted to Consortia Assembly on 2026-10-09

# Builds on Excel-/ Google Sheets Template by C. Schmidt (NFDI4BioImage)


# Expected filename structure:
# Consortium-ServiceCategory-Service-NFDI_Diensteportfolio_Kriterien_FeedbackForm-v0.9.xlsx
#
# Parsing rule:
# - consortium = everything before the first "-"
# - ServiceCategory = a service category from Table 5 in https://doi.org/10.5281/zenodo.10101412
# - service    = everything between that first "-" and
#                "-NFDI_Diensteportfolio"
# 
# -            = remaining filename can be changed at liberty.
#
# Service names may therefore contain hyphens; consortium names may not.

filename_pattern <- paste0(
  "^([^-]+)-([^-]+)-(.+)",
  "-NFDI_Diensteportfolio*",
  ".*\\.(?:xlsx|xlsm|xls)$"
)


#input_dir <- "path/to/excel/files"
input_dir <- getwd()


# Short English names, in the criterion order of the template.
# Each name is one word; sheet number + name identifies the criterion.
criterion_key <- tibble::tribble(
  ~sheet_no, ~keywords,
  "01", "maturity,updates,stack,architecture,quality,stability",
  "02", "availability,resilience,backups",
  "03", "safeguards,isms,certification,contact,response",
  "04", "imprint,provider,owner,privacy,security,incidents,consortia",
  "05", "privacy",
  "06", "visibility,response",
  "07", "usability,consistency,accessibility,responsiveness,efficiency,language",
  "08", "guidance,features,scope,code,interfaces",
  "09", "coverage,tailoring,reusability,uptodatedness",
  "10", "standards,technical,semantic,operational",
  "11", "purpose,audience,value",
  "12", "acceptance,measurement,indicators,assessment",
  "13", "availability,operators,alignment",
  "14", "foundation,classification,repository",
  "15", "nonprofit,commercialuse,feemodel"
) |>
  separate_longer_delim(keywords, delim = ",") |>
  rename(keyword = keywords) |>
  group_by(sheet_no) |>
  mutate(criterion_no = row_number()) |>
  ungroup() |>
  mutate(
    criterion_id = str_c("s", sheet_no, "_", keyword)
  )

# Functions
# Read one criterion sheet ---------------------------------------------

read_criterion_sheet <- function(path, sheet) {
  
  sheet_no <- str_extract(sheet, "^\\d{2}")
  
  # Explicitly read A:G, including empty response columns.
  # All columns are text to avoid inconsistent types across workbooks.
  dat <- read_excel(
    path = path,
    sheet = sheet,
    range = cell_limits(c(6, 1), c(NA, 7)),
    col_names = c(
      "criterion_de",
      "criterion_en",
      "clarity",
      "applicable",
      "workload",
      "answer",
      "comment"
    ),
    col_types = rep("text", 7),
    trim_ws = TRUE
  ) |>
    filter(
      !is.na(criterion_en),
      str_trim(criterion_en) != ""
    ) |>
    mutate(
      sheet_no = sheet_no,
      sheet_name = sheet,
      criterion_no = row_number()
    )
  
  expected_n <- criterion_key |>
    filter(.data$sheet_no == .env$sheet_no) |>
    nrow()
  
  # Do not silently mislabel criteria if the template has changed.
  if (nrow(dat) != expected_n) {
    stop(
      "Unexpected number of criteria in '", basename(path),
      "', sheet '", sheet, "': expected ", expected_n,
      ", found ", nrow(dat), ".",
      call. = FALSE
    )
  }
  
  dat |>
    left_join(
      criterion_key,
      by = c("sheet_no", "criterion_no")
    )
}


# Read one workbook ---------------------------------------------------

read_workbook <- function(path) {
  
  filename <- basename(path)
  
  metadata <- str_match(
    filename,
    regex(filename_pattern, ignore_case = TRUE)
  )
  
  if (is.na(metadata[1, 1])) {
    stop(
      "Filename does not match the expected pattern: ",
      filename,
      "\nExpected: Consortium-ServiceCategory-Service-",
      "NFDI_Diensteportfolio_Kriterien_FeedbackForm-v0.9.xlsx",
      call. = FALSE
    )
  }
  
  consortium_name <- str_trim(metadata[1, 2])
  category_name   <- str_trim(metadata[1, 3])
  service_name    <- str_trim(metadata[1, 4])
  
  sheets <- excel_sheets(path) |>
    str_subset("^(0[1-9]|1[0-5])(?:\\D|$)")
  
  sheet_numbers <- str_extract(sheets, "^\\d{2}")
  
  if (
    length(sheets) != 15L ||
    anyDuplicated(sheet_numbers) > 0L ||
    !setequal(sheet_numbers, sprintf("%02d", 1:15))
  ) {
    stop(
      "Expected exactly one sheet for each number 01–15 in: ",
      filename,
      call. = FALSE
    )
  }
  
  map(sheets, \(sheet) read_criterion_sheet(path, sheet)) |>
    bind_rows() |>
    mutate(
      source_file = filename,
      consortium = consortium_name,
      servicecategory = category_name,
      service = service_name,
      .before = 1
    )
}


# ======================================#
# Workflow
# Find and import all matching workbooks -------------------------------

files <- list.files(
  path = input_dir,
  pattern = "\\.(xlsx|xlsm|xls)$",
  full.names = TRUE,
  ignore.case = TRUE
)

# Exclude Excel's temporary lock files.
files <- files[!str_detect(basename(files), "^~\\$")]

# Only import workbooks following the feedback-form naming convention.
files <- files[
  str_detect(
    basename(files),
    regex(filename_pattern, ignore_case = TRUE)
  )
]

if (length(files) == 0L) {
  stop("No matching feedback workbooks found in: ", input_dir)
}

# One row per criterion per workbook; useful for analysis and checking.
feedback_long <- files |>
  map(read_workbook) |>
  bind_rows() |> 
  mutate(across(where(is.character), str_to_lower)) |>
  mutate(across(
    matches("_(clarity|applicable|workload|answer)$"),
    ~ case_when(
      str_trim(.x) %in% c("yes", "high")      ~ 1,
      str_trim(.x) %in% c("no", "low")        ~ 0,
      str_trim(.x) %in% c("partly", "medium") ~ 0.5,
      str_trim(.x) == "not relevant"         ~ 88888,
      TRUE                                  ~ NA_real_
    )
  ))


# Reshape to one row per workbook/service ------------------------------

feedback_wide <- files |>
  map(function(path) {
    
    read_workbook(path) |>
      select(
        source_file,
        consortium,
        servicecategory,
        service,
        criterion_id,
        clarity,
        applicable,
        workload,
        answer,
        comment
      ) |>
      pivot_wider(
        id_cols = c(
          source_file,
          consortium,
          servicecategory,
          service
        ),
        names_from = criterion_id,
        values_from = c(
          clarity,
          applicable,
          workload,
          answer,
          comment
        ),
        names_glue = "{criterion_id}_{.value}",
        names_vary = "slowest"
      )
    
  }) |>
  bind_rows() |>
  mutate(across(where(is.character), str_to_lower)) |>
  mutate(across(
    matches("_(clarity|applicable|workload|answer)$"),
    ~ case_when(
      str_trim(.x) %in% c("yes", "high", "heavy") ~ 1,
      str_trim(.x) %in% c("no", "low")           ~ 0,
      str_trim(.x) %in% c("partly", "medium")    ~ 0.5,
      str_trim(.x) == "not relevant"            ~ 88888,
      TRUE                                     ~ NA_real_
    )
  ))

stopifnot(
  nrow(feedback_wide) == length(files),
  !anyDuplicated(feedback_wide$source_file)
)

# Save to csv file

savefile <- paste0(today(),"_OverviewNFDIPortfolioEvaluations")

feedback_wide |> 
  write.csv2(savefile)

