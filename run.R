#!/usr/bin/env Rscript

pr <- plumber::plumb("plumber.R")
pr$run(host = "172.16.7.127", port = 8000)
