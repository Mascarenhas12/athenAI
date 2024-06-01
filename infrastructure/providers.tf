provider "google" {
  project     = local.project_id
  region      = local.region
  credentials = "credentials.json"
}

provider "google-beta" {
  project     = local.project_id
  region      = local.region
  credentials = "credentials.json"
}