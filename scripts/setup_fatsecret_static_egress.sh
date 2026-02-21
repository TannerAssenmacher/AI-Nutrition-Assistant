#!/usr/bin/env bash
set -euo pipefail

# Run this in Google Cloud Shell (or any machine with gcloud + auth).

PROJECT_ID="${PROJECT_ID:-ai-nutrition-assistant-e2346}"
REGION="${REGION:-us-central1}"
NETWORK="${NETWORK:-default}"
STATIC_IP_NAME="${STATIC_IP_NAME:-fatsecret-egress-ip}"
CONNECTOR_NAME="${CONNECTOR_NAME:-fatsecret-egress-conn}"
CONNECTOR_RANGE="${CONNECTOR_RANGE:-10.8.0.0/28}"
CONNECTOR_MACHINE_TYPE="${CONNECTOR_MACHINE_TYPE:-e2-micro}"
CONNECTOR_MIN_INSTANCES="${CONNECTOR_MIN_INSTANCES:-2}"
CONNECTOR_MAX_INSTANCES="${CONNECTOR_MAX_INSTANCES:-3}"
ROUTER_NAME="${ROUTER_NAME:-fatsecret-egress-router}"
NAT_NAME="${NAT_NAME:-fatsecret-egress-nat}"

echo "Using project=${PROJECT_ID} region=${REGION} network=${NETWORK}"
gcloud config set project "${PROJECT_ID}" >/dev/null

if ! gcloud compute addresses describe "${STATIC_IP_NAME}" --region "${REGION}" >/dev/null 2>&1; then
  gcloud compute addresses create "${STATIC_IP_NAME}" \
    --region "${REGION}"
fi

if ! gcloud compute networks vpc-access connectors describe "${CONNECTOR_NAME}" --region "${REGION}" >/dev/null 2>&1; then
  gcloud compute networks vpc-access connectors create "${CONNECTOR_NAME}" \
    --region "${REGION}" \
    --network "${NETWORK}" \
    --range "${CONNECTOR_RANGE}" \
    --machine-type "${CONNECTOR_MACHINE_TYPE}" \
    --min-instances "${CONNECTOR_MIN_INSTANCES}" \
    --max-instances "${CONNECTOR_MAX_INSTANCES}"
fi

if ! gcloud compute routers describe "${ROUTER_NAME}" --region "${REGION}" >/dev/null 2>&1; then
  gcloud compute routers create "${ROUTER_NAME}" \
    --network "${NETWORK}" \
    --region "${REGION}"
fi

if ! gcloud compute routers nats describe "${NAT_NAME}" --router "${ROUTER_NAME}" --router-region "${REGION}" >/dev/null 2>&1; then
  gcloud compute routers nats create "${NAT_NAME}" \
    --router "${ROUTER_NAME}" \
    --router-region "${REGION}" \
    --nat-all-subnet-ip-ranges \
    --nat-external-ip-pool "${STATIC_IP_NAME}"
else
  gcloud compute routers nats update "${NAT_NAME}" \
    --router "${ROUTER_NAME}" \
    --router-region "${REGION}" \
    --nat-all-subnet-ip-ranges \
    --nat-external-ip-pool "${STATIC_IP_NAME}"
fi

STATIC_IP="$(gcloud compute addresses describe "${STATIC_IP_NAME}" --region "${REGION}" --format='value(address)')"
echo "Static egress IP ready: ${STATIC_IP}"
echo "Allowlist this as ${STATIC_IP}/32 in FatSecret."
