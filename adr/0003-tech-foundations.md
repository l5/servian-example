# 1. Tech foundations decision

Date: 2022-03-12

## Status

Accepted

## Context

The solution could be built based on

* VMSS
* ACI
* Web App
* K8s

## Decision

I will use Azure Web App, as that is sold by MS as exactly fit to purpose for deploying a comparatively simple web app, and is easier (= faster) to configure than k8s.

## Consequences

We have to stick to the frameworks and limits of the Azure Web App.