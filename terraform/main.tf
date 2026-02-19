terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.3.0"
}

# Используйте файл key.json, который мы создали ранее
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

provider "github" {
  token = var.github_token
}

# Используем существующую сеть (обычно 'default')
data "yandex_vpc_network" "default" {
  name = "default"
}

# Создание подсети
resource "yandex_vpc_subnet" "lab_subnet" {
  name           = "lab-subnet"
  zone           = var.zone
  network_id     = data.yandex_vpc_network.default.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# Группа безопасности временно удалена из-за ограничений прав. 
# ВМ будет использовать 'default' группу безопасности сети.

# Получение последнего образа Ubuntu
data "yandex_compute_image" "ubuntu_image" {
  family = "ubuntu-2204-lts"
}

# Создание виртуальной машины
resource "yandex_compute_instance" "lab_vm" {
  name        = "lab-vm-terraform"
  platform_id = "standard-v2"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20 # Бесплатный тариф
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_image.id
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.lab_subnet.id
    nat       = true # Публичный IP
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }

  scheduling_policy {
    preemptible = true # Для экономии средств (прерываемая ВМ)
  }
}