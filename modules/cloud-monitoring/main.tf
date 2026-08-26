terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

locals {
  database_id = "${var.project_id}:${var.db_instance_name}"
  url_map     = "${var.name_prefix}-lb-urlmap"

  lb_filter  = "resource.type=\"https_lb_rule\" AND resource.label.\"url_map_name\"=\"${local.url_map}\""
  sql_filter = "resource.type=\"cloudsql_database\" AND resource.label.\"database_id\"=\"${local.database_id}\""
  # gce_instance carries no environment label, so scope by name.
  vm_filter = "resource.type=\"gce_instance\" AND metric.label.\"instance_name\"=starts_with(\"${var.name_prefix}-\")"
}

resource "google_monitoring_notification_channel" "email" {
  count = var.notification_email != null && var.notification_email != "" ? 1 : 0

  project      = var.project_id
  display_name = "${var.name_prefix} email"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_dashboard" "this" {
  project = var.project_id

  dashboard_json = jsonencode({
    displayName = "PetClinic ${var.environment} — GCP view"
    mosaicLayout = {
      columns = 12
      tiles = [
        # ---- Application uptime -------------------------------------------
        {
          xPos = 6, yPos = 0, width = 6, height = 4
          widget = {
            title = "Application uptime — requests by response class"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" AND ${local.lb_filter}"
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.\"response_code_class\""]
                    }
                  }
                }
                plotType   = "STACKED_AREA"
                targetAxis = "Y1"
              }]
              yAxis = { label = "requests/s", scale = "LINEAR" }
            }
          }
        },
        {
          xPos = 0, yPos = 4, width = 6, height = 4
          widget = {
            title = "Application uptime — round trip through the load balancer"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"loadbalancing.googleapis.com/https/total_latencies\" AND ${local.lb_filter}"
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }]
              yAxis = { label = "ms (p95)", scale = "LINEAR" }
            }
          }
        },

        # ---- Resource usage -----------------------------------------------
        {
          xPos = 6, yPos = 4, width = 6, height = 4
          widget = {
            title = "Resource usage — VM CPU"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND ${local.vm_filter}"
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["metric.label.\"instance_name\""]
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }]
              yAxis = { label = "fraction of 1 vCPU", scale = "LINEAR" }
            }
          }
        },
        {
          xPos = 0, yPos = 20, width = 12, height = 4
          widget = {
            title = "Resource usage — memory and disk"
            text = {
              format = "MARKDOWN"
              content = join("\n", [
                "### Memory and disk are in Grafana, not here",
                "",
                "Google reports CPU for every VM from the hypervisor, for free. Memory and",
                "disk are different: they can only be seen from **inside** the guest, which",
                "needs the Ops Agent, and no VM in this project runs one. Installing it on the",
                "application VMs means rebuilding the baked image.",
                "",
                "`node_exporter` already reports both, and Prometheus already scrapes it, so",
                "the numbers exist — they are on the **PetClinic - rollout & health**",
                "dashboard in Grafana, reached over the IAP tunnel. See `docs/monitoring.md`.",
                "",
                "The honest boundary: Prometheus sees inside the guest, this view sees",
                "what Google sees — and only this view alerts. Prometheus never does.",
              ])
            }
          }
        },

        # ---- Database ------------------------------------------------------
        {
          xPos = 0, yPos = 12, width = 6, height = 4
          widget = {
            title = "Database — queries per second"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"cloudsql.googleapis.com/database/mysql/queries\" AND ${local.sql_filter}"
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType       = "LINE"
                  targetAxis     = "Y1"
                  legendTemplate = "all queries"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"cloudsql.googleapis.com/database/mysql/dml_operations_count\" AND ${local.sql_filter}"
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                      }
                    }
                  }
                  plotType       = "LINE"
                  targetAxis     = "Y1"
                  legendTemplate = "writes (DML)"
                },
              ]
              yAxis = { label = "queries/s", scale = "LINEAR" }
            }
          }
        },
        {
          xPos = 6, yPos = 12, width = 6, height = 4
          widget = {
            title = "Database — latency signals"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"cloudsql.googleapis.com/database/mysql/slow_queries_count\" AND ${local.sql_filter}"
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType       = "LINE"
                  targetAxis     = "Y1"
                  legendTemplate = "slow queries/s"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"cloudsql.googleapis.com/database/mysql/innodb/row_lock_waits_count\" AND ${local.sql_filter}"
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType       = "LINE"
                  targetAxis     = "Y2"
                  legendTemplate = "row lock waits/s"
                },
              ]
              # MySQL publishes no per-query latency; these are the two
              # latency signals that carry data here.
              yAxis  = { label = "slow queries/s", scale = "LINEAR" }
              y2Axis = { label = "lock waits/s", scale = "LINEAR" }
            }
          }
        },
        {
          xPos = 0, yPos = 16, width = 6, height = 4
          widget = {
            title = "Database — CPU and memory"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" AND ${local.sql_filter}"
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_MEAN"
                      }
                    }
                  }
                  plotType       = "LINE"
                  targetAxis     = "Y1"
                  legendTemplate = "cpu"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"cloudsql.googleapis.com/database/memory/utilization\" AND ${local.sql_filter}"
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_MEAN"
                      }
                    }
                  }
                  plotType       = "LINE"
                  targetAxis     = "Y1"
                  legendTemplate = "memory"
                },
              ]
              yAxis = { label = "fraction", scale = "LINEAR" }
            }
          }
        },
        {
          xPos = 6, yPos = 16, width = 6, height = 4
          widget = {
            title = "Database — connections"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"cloudsql.googleapis.com/database/mysql/connections_count\" AND ${local.sql_filter}"
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
                plotType       = "LINE"
                targetAxis     = "Y1"
                legendTemplate = "new connections/s"
              }]
              yAxis = { label = "connections/s", scale = "LINEAR" }
            }
          }
        },

        # ---- Rollout and logs ----------------------------------------------
        {
          xPos = 0, yPos = 0, width = 6, height = 4
          widget = {
            title = "Rollout — instances reporting"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    # Counting series rather than reading a value: every running
                    # instance reports CPU, so the count is the fleet size. A
                    # rolling deploy surges it before it removes anything.
                    filter = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND ${local.vm_filter}"
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_COUNT"
                    }
                  }
                }
                plotType       = "LINE"
                targetAxis     = "Y1"
                legendTemplate = "instances"
              }]
              yAxis = { label = "instances", scale = "LINEAR" }
            }
          }
        },
        {
          xPos = 0, yPos = 8, width = 12, height = 4
          widget = {
            title = "Application logs — requests through the load balancer"
            logsPanel = {
              # The load balancer writes these itself; nothing is installed on a
              # VM to produce them. Sampled at 50%, so this is a representative
              # view rather than a complete one.
              filter = join("\n", [
                "resource.type=\"http_load_balancer\"",
                "resource.labels.url_map_name=\"${local.url_map}\"",
              ])
              resourceNames = ["projects/${var.project_id}"]
            }
          }
        },
      ]
    }
  })
}

resource "google_monitoring_alert_policy" "high_cpu" {
  project      = var.project_id
  display_name = "${var.name_prefix} — high CPU"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Instance CPU above ${var.cpu_threshold * 100}% for ${var.alert_duration}"

    condition_threshold {
      filter          = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND ${local.vm_filter}"
      comparison      = "COMPARISON_GT"
      threshold_value = var.cpu_threshold
      duration        = var.alert_duration

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["metric.label.instance_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email[*].id

  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      Hypervisor-level CPU for one VM in ${var.environment} has been above
      ${var.cpu_threshold * 100}% for ${var.alert_duration}.

      Measured by the hypervisor, so a wedged VM cannot suppress it.

      **The only CPU alert in the project.** Prometheus scrapes the same
      condition from inside the guest but evaluates no rules; per-VM detail,
      memory and disk included, is on *PetClinic - rollout & health* in
      Grafana.
    EOT
  }
}

resource "google_monitoring_alert_policy" "application_downtime" {
  project      = var.project_id
  display_name = "${var.name_prefix} — application downtime"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Load balancer serving more than ${var.error_rate_threshold} 5xx per second"

    condition_threshold {
      filter          = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" AND ${local.lb_filter} AND metric.label.\"response_code_class\"=\"500\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.error_rate_threshold
      duration        = var.error_alert_duration

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email[*].id

  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      The load balancer in ${var.environment} returned server errors at more
      than ${var.error_rate_threshold}/s - over six in a minute - in a single
      60-second window.

      **This signal depends on traffic.** It measures errors in requests that
      were actually made, so an application that is completely down on a quiet
      system produces no requests, no 5xx, and no incident here. That is
      why the traffic-independent signal is the `application unreachable`
      policy, driven by the uptime check: Google's probers request the load
      balancer on their own schedule, whether or not anyone is using it.

      Read this one as "users are being served errors", not as "the
      application is up".
    EOT
  }
}

# The external view, from outside the VPC. Google's own probers request the load
# balancer on a timer, so this fires whether or not anyone is using the system —
# which is the gap the 5xx policy above cannot close.
#
# Deliberately unauthenticated. IAP answers an anonymous request with a 302 to
# the Google sign-in page, and that 302 is the healthy result: it proves DNS,
# the certificate, the forwarding rule and that IAP is still enforcing. A 200
# here would mean IAP had been turned off, so this check doubles as a detector
# for that. Proving the backend served the request is the scrape's job, not
# this one's, and buying that proof would mean an ID token living somewhere.
resource "google_monitoring_uptime_check_config" "lb" {
  project      = var.project_id
  display_name = "${var.name_prefix} — load balancer reachable"
  timeout      = "10s"
  period       = var.uptime_period

  http_check {
    path           = "/"
    port           = 443
    use_ssl        = true
    request_method = "GET"

    # The certificate is self-signed for the sslip.io name while there is no
    # domain to get a managed one for, so Google cannot chain it to a root.
    validate_ssl = false

    accepted_response_status_codes {
      status_value = 302
    }
  }

  monitored_resource {
    type = "uptime_url"

    labels = {
      project_id = var.project_id
      host       = var.lb_host
    }
  }
}

resource "google_monitoring_alert_policy" "uptime" {
  project      = var.project_id
  display_name = "${var.name_prefix} — application unreachable"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Uptime check failing for ${var.alert_duration}"

    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\"",
        "resource.type=\"uptime_url\"",
        "metric.label.\"check_id\"=\"${google_monitoring_uptime_check_config.lb.uptime_check_id}\"",
      ])
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = var.alert_duration

      # Fraction of probers that got the expected answer, over the window. Any
      # region failing pulls this under 1, so a partial outage still opens an
      # incident.
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_FRACTION_TRUE"
        cross_series_reducer = "REDUCE_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email[*].id

  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      Google's uptime probers can no longer reach the ${var.environment} load
      balancer at `${var.lb_host}`.

      Unlike the 5xx policy, this one does not depend on traffic: the probers
      request the load balancer on their own schedule, so it fires on a quiet
      system too. It is the answer to "is the application reachable at all".

      The check expects a **302** — IAP redirecting an anonymous request to the
      Google sign-in page. Two ways it opens:

      - **No answer, or a TLS failure.** The load balancer, the forwarding rule
        or the certificate. Start with `gcloud compute forwarding-rules list`.
      - **A 200 instead of a 302.** IAP is no longer enforcing on this backend.
        Treat that as a security incident, not an availability one.

      Whether the application behind IAP is actually serving is a separate
      question, and nothing alerts on it. Check *PetClinic - rollout & health*
      in Grafana, or ask the load balancer with
      `gcloud compute backend-services get-health`.
    EOT
  }
}
