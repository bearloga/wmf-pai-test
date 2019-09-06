library(plumber)

library(glue)

log_filename <- "/usr/local/plumber/test/requests.log"

style <- "<style>
body { font-family: sans; }
</style>"
html <- "<!DOCTYPE html>
<html>
<head>
<title>Logged requests | Product Analytics Infrastructure</title>
{style}
</head>
<body>
{table}
</body>
</html>"

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
    reqs <- read.delim(log_filename, header = FALSE, col.names = c("timestamp", "user_agent", "post_body"))
    table <- knitr::kable(reqs, 'html')
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
    reqs <- read.delim(log_filename, header = FALSE, col.names = c("timestamp", "user_agent", "post_body"))
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