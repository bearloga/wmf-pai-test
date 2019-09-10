library(plumber)
library(glue)
library(magrittr)
library(knitr)
library(kableExtra)

log_filename <- "/usr/local/plumber/test/requests.log"

style <- '<style type="text/css">
body { padding: 15px; font-family: sans-serif; font-size: 14px; text-align: left; }
pre { font-size: 12px; padding: 5px; }
td { padding: 0 20px; }
.table-striped>tbody>tr:nth-child(odd)>td { background-color: #f9f8f7; }
</style>'
html <- '<!DOCTYPE html>
<html>
<head>
<title>Logged requests | Product Analytics Infrastructure</title>
{style}
</head>
<body>
{table}
</body>
</html>'

#* @apiTitle Test API

#* Log the request to a file
#* @post /log
function(req) {
  # write(paste0(Sys.time(), ": ", req), "~/Desktop/test/requests.log", append = TRUE)
  sink(file = log_filename, append = TRUE)
  cat(as.character(Sys.time()), "\t", urltools::url_decode(req$HTTP_USER_AGENT), "\t", req$postBody, "\n", sep = "")
  sink()
}

#* View logged requests
#* @get /view
#* @html
function() {
  if (file.exists(log_filename)) {
    reqs <- log_filename %>%
      readr::read_tsv(col_names = c("timestamp", "user_agent", "post_body"), col_types = "Tcc") %>%
      dplyr::mutate(post_body = paste0("<pre>", purrr::map_chr(post_body, jsonlite::prettify), "</pre>")) %>%
      dplyr::arrange(dplyr::desc(timestamp))
    table <- reqs %>%
      kable("html", escape = FALSE, col.names = c("Received (UTC, DESC)", "UserAgent", "POST body")) %>%
      kable_styling(bootstrap_options = c("striped"), full_width = TRUE) %>%
      column_spec(1, width = "180px") %>%
      column_spec(2, width = "380px")
  } else {
    table <- "<p>Request log empty</p>"
  }
  return(glue(html))
}

#* Clear request log
#* @get /clear
function() {
  if (file.exists(log_filename)) {
    file.remove(log_filename)
  }
}

#* Clear logged requests but retain some
#* @get /retain/<leave>
function(leave) {
  leave <- as.integer(leave)
  if (file.exists(log_filename) && leave > 0) {
    reqs <- read.delim(log_filename, header = FALSE, col.names = c("timestamp", "user_agent", "post_body"), stringsAsFactors = FALSE)
    write.table(tail(reqs, leave), log_filename, row.names = FALSE, col.names = FALSE, sep = "\t")
  }
}

#* Fetch stream configuration
#* @get /streams
#* @serializer unboxedJSON
function() {
  if (file.exists("stream-config.yaml")) {
    return(yaml::read_yaml("stream-config.yaml"))
  }
}
