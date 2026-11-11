# NFDI Service Feedback Import

Imports Excel feedback forms from a directory and combines sheets 01–15 into one wide dataset (`feedback_wide`): one row per Excel file, with separate columns for each criterion and response field.

## File naming convention

Name files as follows:

``` text
Consortium-ServiceCategory-Service-NFDI_Diensteportfolio_Kriterien_FeedbackForm-v0.9.xlsx
```

Replace the first three components; leave the rest unchanged:

| Component         | Content                                      |
|-------------------|----------------------------------------------|
| `Consortium`      | Name of the NFDI consortium                  |
| `ServiceCategory` | Filename token from the category table below |
| `Service`         | Name of the service being assessed           |

Naming rules:

- Do not use hyphens within consortium or category names.
- Use the category tokens exactly as listed below; spaces and slashes are replaced with underscores.
- Service names may contain hyphens.
- Submit one workbook per service, using one category token.

### Service categories

The categories below are taken from Table 5 of *White paper: Interim report reference* (Amelung et al., 2023). The paper describes them as categories of service components.

| Category in Table 5 | Filename token | Brief description |
|------------------------|------------------------|------------------------|
| Databases | `Databases` | Software providing structured data from repositories and archives, usually with browser-based upload, access, search, or download. |
| Libraries/API | `Libraries_API` | Pre-implemented functions accessible through a well-defined interface. |
| Workflows/Pipelines | `Workflows_Pipelines` | Software combining multiple tools or applications, executed locally or remotely. |
| Tools/Applications | `Tools_Applications` | Software downloaded and executed locally on users’ hardware. |
| Web applications | `Web_applications` | Server-hosted software accessed through a web page, including software as a service. |
| Support/Consulting | `Support_Consulting` | Direct user support extending beyond assistance for individual services. |
| Data Curation | `Data_Curation` | Managing, enriching, and maintaining data for discovery and reuse, where not included in support or consulting. |
| Training | `Training` | Standalone training and educational materials covering research data management. |
| Storage | `Storage` | Research-data storage provided to external users and accessible through web protocols. |


### Example

For the consortium NFDI4Chem, category Databases, and an illustrative service named ExampleService:

``` text
NFDI4Chem-Databases-ExampleService-NFDI_Diensteportfolio_Kriterien_FeedbackForm-v0.9.xlsx
```

The imported metadata will be:

``` text
consortium      = nfdi4chem
servicecategory = databases
service         = exampleservice
```

## Variable key

| Variable | Description |
|------------------------------------|------------------------------------|
| `source_file` | Source workbook filename |
| `consortium` | Consortium extracted from the filename |
| `servicecategory` | Category token extracted from the filename; underscores are preserved |
| `service` | Service name extracted from the filename |
| `sNN_keyword_field` | Sheet number, short English criterion name, and response field |

Criterion variables follow this structure:

``` text
sNN_keyword_field
```

- `NN`: sheet number, from `01` to `15`.
- `keyword`: short, one-word English criterion name defined in `criterion_key`.
- `field`: response field listed below.

Example: `s01_maturity_clarity` contains the clarity response for the maturity criterion in sheet 01.

| Field suffix | Excel column | Description |
|----|----|----|
| `clarity` | C | Is the criterion clear? |
| `applicable` | D | Can the criterion be applied to the service? |
| `workload` | E | Workload associated with the criterion |
| `answer` | F | Is a discrete answer to the criterion already known? |
| `comment` | G | Free-text comment; not numerically recoded |

## Numeric codes

Response fields are converted to lowercase, trimmed, and recoded as follows:

| Response                                 |  Code |
|------------------------------------------|------:|
| `yes`, `high`, `heavy`                   |     1 |
| `no`, `low`                              |     0 |
| `partly`, `medium`                       |   0.5 |
| `not relevant`                           | 88888 |
| Missing, blank, or unrecognised response |  `NA` |

- Numeric recoding applies only to `clarity`, `applicable`, `workload`, and `answer`. Comments remain text.
- `88888` is a special code, not a score. Exclude it from numerical summaries such as means.
- For workload variables, higher values indicate greater workload, not a more favourable assessment.

## Usage and assumptions

1.  Install `dplyr`, `tidyr`, `purrr`, `stringr`, and `readxl`.
2.  Set `input_dir` to the directory containing the completed workbooks.
3.  Run the script. The final dataset is stored in `feedback_wide` and saved with the current date in a csv-file named `DATE_OverviewNFDIPortfolioEvaluations`.

The script expects:

- Exactly one sheet for each number from 01 to 15.
- Headers in row 5 and criteria starting in row 6.
- The original criterion order used in `criterion_key`.

Sheet numbers and criterion counts are checked, but reordered criteria are not detected. Each workbook remains a separate row, including multiple workbooks for the same consortium and service.

## Reference

Amelung, L., Anthofer, V., Danabalan, R., Demandt, É., Ebert, B., Elschner, E., Espinoza, S., Eufinger, J., Fuchsloch, S., Götz, B., Henzen, C., Hunold, J., Idda, T., Jansen, L., Krieger, U., Rodrigues, C. M., Meister, M., Miller, B., Pittroff, S., . . . Zinke, W. (2023). *White paper: Interim report reference*. Zenodo. <https://doi.org/10.5281/zenodo.10101412>
