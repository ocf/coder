terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.4.15"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.12.1"
    }
  }
}

variable "namespace" {
  type        = string
  sensitive   = true
  description = "The namespace to create workspaces in (must exist prior to creating workspaces)"
  default     = "app-coder-workspaces"
}

provider "kubernetes" {
  config_path = null
}

data "coder_workspace" "me" {}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<EOT
    #!/bin/bash

    # home folder can be empty, so copying default bash settings
    if [ ! -f ~/.profile ]; then
      cp /etc/skel/.profile $HOME
    fi
    if [ ! -f ~/.bashrc ]; then
      cp /etc/skel/.bashrc $HOME
    fi

    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh | tee code-server-install.log
    code-server --auth none --port 13337 | tee code-server-install.log &

    # clone ocfstatic
    git clone https://github.com/ocf/ocfstatic.git --branch gatsby-dev $HOME/ocfstatic
    # this is a nasty hack since ssh prompts to trust host on first connect and this script runs noninteractively
    (cd $HOME/ocfstatic && git remote set-url origin "git@github.com:ocf/ocfstatic.git")

    # update ocfstatic
    (cd $HOME/ocfstatic && git fetch && git pull --ff-only)
    (cd $HOME/ocfstatic && yarn)
  EOT
}

# code-server
resource "coder_app" "code-server" {
  agent_id      = coder_agent.main.id
  name          = "code-server"
  icon          = "/icon/code.svg"
  url           = "http://localhost:13337?folder=/home/coder/ocfstatic"
  relative_path = true
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}-home"
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
    storage_class_name = "managed-nfs-storage"
  }
}

resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    namespace = var.namespace
  }
  spec {
    security_context {
      run_as_user = "1000"
      fs_group    = "1000"
    }
    container {
      name    = "dev"
      image   = "docker.ocf.berkeley.edu/coder/ocfstatic:latest"
      command = ["sh", "-c", coder_agent.main.init_script]
      security_context {
        run_as_user = "1000"
      }
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        read_only  = false
      }
      resources {
        requests = {
          cpu               = "4"
          memory            = "4Gi"
          ephemeral-storage = "500Mi"
        }
        limits = {
          cpu               = "8"
          memory            = "6Gi"
          ephemeral-storage = "1Gi"
        }
      }
    }
    priority_class_name = "coder-workspace-priority"

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
        read_only  = false
      }
    }
  }
}
