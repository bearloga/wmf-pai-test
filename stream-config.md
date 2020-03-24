# Stream configuration scenarios

**Table of Contents**:

- [Editing behavior](#Editing-behavior)
    - [Growth team experiments](#Growth-team-experiments)
- [Reading behavior](#Reading-behavior)
    - [Web team experiments](#Web-team-experiments)

## Editing behavior

```yaml
edit:
  $schema: /edit/attempt-step/0.0.1
  destination: https://pai-test.wmflabs.org/log
  sampling:
    rate: 0.1
    rules:
      - wiki:
          - en.wikipedia.org
        rate: 0.01
edit.apps:
  $schema: /edit/attempt-step/0.0.1
  destination: https://pai-test.wmflabs.org/log
  sampling:
    rate: 0.0
    rules:
     - platform:
         - ios
         - android
       rate: 1.0
```

In this case, we have 2 streams:

- Of sessions generating data for the `edit` stream, only 10% have their data sent. On English Wikipedia, it's only 1% of sessions.
- Events logged to `edit` stream will be cc'd to the `edit.apps` stream, but only those on the iOS and Android platforms will actually be determined to be in-sample and then sent.

### Growth team experiments

Suppose Growth wants to gather more editing behavior data on the Czech and Korean Wikipedias, not subject to the sampling rates of the `edit` stream. They can accomplish it as follows:

```yaml
edit.growth:
  $schema: /edit/attempt-step/0.0.1
  destination: https://pai-test.wmflabs.org/log
  sampling:
    rate: 0.0
    rules:
      - wiki:
          - cz.wikipedia.org
          - ko.wikipedia.org
        platform:
          - desktop
          - mobile web
        rate: 1.0
```

Now suppose they want to have a separate table that's just the editing behavior of users who have been enrolled in a randomized controlled experiment. Events posted to `edit.growth` will be cc'd to `edit.growth.help_panel`, but only sent if the key-value store has one of three possible values for the `growth_experiment` key:

```yaml
edit.growth.help_panel:
  $schema: /edit/attempt-step/0.0.1
  destination: https://pai-test.wmflabs.org/log
  sampling:
    rate: 0.0
    identifier: session
    rules:
      - wiki:
          - cz.wikipedia.org
          - ko.wikipedia.org
        key: growth_experiment
        value:
          - baseline
          - variant_1
          - variant_2
        platform:
          - desktop
          - mobile web
        rate: 1.0
```

**NOTE**: EPC does not know where the `key` is stored. Growth team uses the [user properties table](https://www.mediawiki.org/wiki/Manual:User_properties_table) in MediaWiki. On the web, we might want to make EPC have access to values persisted with `mw.cookie.set` and leave it up to Growth's engineers to write their instrumentation so that it pulls the relevant marker out of user properties and stores it in a session cookie for EPC to check against.

## Reading behavior

Suppose we deploy `reading_depth` instrumentation across all wikis, but want different sampling rates for certain wikis:

```yaml
reading_depth
  $schema: /web/reading-depth/0.0.1
  destination: https://pai-test.wmflabs.org/log
  sampling:
    rate: 0.5
    rules:
      - wiki:
          - *.wikipedia.org
        rule: 0.25
      - wiki:
          - en.wikipedia.org
        rate: 0.01
      - wiki:
          - es.wikipedia.org
          - ja.wikipedia.org
          - de.wikipedia.org
          - ru.wikipedia.org
          - fr.wikipedia.org
          - it.wikipedia.org
          - zh.wikipedia.org
          - pt.wikipedia.org
          - pl.wikipedia.org
        rate: 0.1
```

### Web team experiments

Suppose the Reading/Web team deploys an A/B test of their desktop refresh and they want to collect reading **_and_** editing behavior data to understand how the two variants differ out in the wild:

```yaml
edit.desktop_refresh:
  $schema: /edit/attempt-step/0.0.1
  destination: https://pai-test.wmflabs.org/log
  sampling:
    rate: 0.0
    rules:
      - key: desktop_refresh_rct
        value:
          - variant_a
          - variant_b
        rate: 1.0
      - key: desktop_refresh_rct
        value:
          - variant_a
          - variant_b
        wiki:
          - en.wikipedia.org
        rate: 0.5
reading_depth.desktop_refresh:
  $schema: /web/reading-depth/0.0.1
  destination: https://pai-test.wmflabs.org/log
  sampling:
    rate: 0.0
    rules:
      - key: desktop_refresh_rct
        value:
          - variant_a
          - variant_b
        rate: 1.0
      - key: desktop_refresh_rct
        value:
          - variant_a
          - variant_b
        wiki:
          - en.wikipedia.org
        rate: 0.5
```

Because both streams are, by default, using the session ID as the identifier for determing whether event is in-sample or out-of-sample, users on English Wikipedia will be sending events either to both streams or neither of the two streams.

**NOTE**: The sampling rate for English Wikipedia users who are enrolled in the desktop refresh A/B test is only for determining whether the event is in-sample or out-of-sample, **_not_** whether the user/client is in the A/B test. That part is up to the instrumentation. In this case, there will be users who are enrolled in the A/B test, but whose events don't get sent -- because users are sampled into the A/B test and the test's buckets *by the instrumentation* which has its own sampling logic and rates, and that's the part that sets the `desktop_refresh_rct` key.
