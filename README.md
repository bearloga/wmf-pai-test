# Test endpoint

This repository contains code and instructions for setting up a web API for testing Product Analytics Infrastructure working group's Event Platform Client libraries. It relies on the [{plumber}](https://www.rplumber.io/) package for [R](https://www.r-project.org/).

It makes the following endpoints available at `BASE_URL="https://pai-test.wmflabs.org/"`:

- `/log`: records `POST` body in a log file
- `/view`: displays logged requests as a table in a web page
- `/clear`: empties the requests log
- `/retain/n`: clears the log except the most recent `n` requests
- `/streams`: returns the latest version of [streams configuration](stream-config.yaml) as JSON

For example, to log an event from the browser:

```JS
var url = BASE_URL + "/log",
    event = {
      action: "start",
    };
navigator.sendBeacon(url, JSON.stringify(event))
```

## Setup

### Instance

Create a new Debian Buster instance on [CloudVPS](https://wikitech.wikimedia.org/wiki/Portal:Cloud_VPS) using the [Horizon UI](https://horizon.wikimedia.org/). `m1.small` flavor is fine. Make sure the `default` [security group](https://horizon.wikimedia.org/project/security_groups/) has a rule for Ingress Port 8000 CIDR 0.0.0.0/0 (`ALLOW IPv4 8000/tcp from 0.0.0.0/0`), then set up a DNS hostname in the [web proxies section of Horizon](https://horizon.wikimedia.org/project/proxy/) for the instance and be sure to change the port from 80 (default) to 8000.

### Dependencies

`sudo` while SSH'd to the instance (e.g. `test-endpoint-01.eqiad.wmflabs`):

```bash
deb http://cran.r-project.org/bin/linux/debian buster-cran35/ >> /etc/apt/sources.list
apt-key adv --keyserver keys.gnupg.net --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'

apt-get update

apt-get install r-base r-base-dev libcurl4-openssl-dev libxml2-dev libssl-dev nodejs npm
npm install -g pm2
```

**Note**: see [this page](https://cran.r-project.org/bin/linux/debian/) for more information about installing R on Debian.

Then, in R:

```R
install.packages(c("plumber", "urltools", "yaml", "tidyverse"))
```

### Service

`mkdir /usr/local/plumber` (`chown` if necessary), clone this repo, register the service with pm2, and save the settings in case of reboot:

```bash
git clone https://github.com/bearloga/wmf-pai-test.git /usr/local/plumber/test
pm2 start --interpreter="Rscript" /usr/local/plumber/test/run.R
pm2 save
```

For more information, refer to [pm2 section](https://www.rplumber.io/docs/hosting.html#pm2) in [Plumber's docs](https://www.rplumber.io/docs/).

**Note**: The instance's routable IP is hardcoded in [run.R](run.R). It would need to be changed in case of a new instance. In the future we may want to add an nginx config that reverse proxies from the routable ip to the local service and change the host in run.R back to the default of 127.0.0.1

#### Maintainance

```
cd /usr/local/plumber/test
pm2 restart run.R
```

To schedule `crontab`:

```
*/15 * * * * cd /usr/local/plumber/test && git pull
```

**Note**: may want to consider Puppetizing this so we could use the `notify` metaparameter with a `git` resource to automatically trigger `pm2` to restart if the repository was updated. For now we need to do this manually.
