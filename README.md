# domed-city
Simple CLI application that wraps the Terraform API.

## Purpose

To consolidate, improve and enforce standards around ITV's use of Terraform across product teams.

This gem provides two main functions:

1. Wrap the main Terraform functions (e.g. `plan`, `apply`).
2. Ensure alignment to ITV's Common Platform VPC and environment policy.

## Disclaimer

This gem is very specific to how ITV utilise Terraform so it is unlikely to be useful to others except
to serve as an example of how we do things.

## Naming

From [Wikipedia](https://en.wikipedia.org/wiki/Domed_city):

> ...the dome is airtight and pressurized, creating a habitat that can be controlled for air temperature, composition and quality, typically due to an external atmosphere (or lack thereof) that is inimical to habitation for one or more reasons.

## Installation

Add to your Gemfile:

```
gem 'domed-city'
```

## Usage

For ease of use, type `dome` in the CLI:

```
$ dome

Dome wraps the Terraform API and performs useful stuff.

Usage:
       dome [command]
where [commands] are:
  -p, --plan            Creates a Terraform plan
  -a, --apply           Applies a Terraform plan
  -l, --plan-destroy    Creates a destructive Terraform plan
  -s, --state           Synchronises the Terraform state
  -v, --version         Print version and exit
  -h, --help            Show this message
```
