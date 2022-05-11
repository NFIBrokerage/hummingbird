# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a
Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0 - 2022-05-11

This release marks stability in the API and does not present a functionality
change.

## 0.2.0 - 2021-07-07

### Changed

- GenServer casting pattern refactored to perform the sending of the honeycomb
  event in the process which emitted the event
    - for phoenix telemetry events, this means that the cowboy/phoenix process
      uploads the event to honeycomb, which prevents a centralized GenServer
      from hoarding memory if there are many requests to a Phoenix endpoint

## 0.1.1 - 2021-06-18

### Changed

- the `conn.params` field is now JSON-encoded

## 0.1.0 - 2021-06-15

### Changed

- `:opencensus_honeycomb` dependency updated to `~> 0.3`
