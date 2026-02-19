import pulumi
import pulumi_yandex as yandex
import os

# Получаем конфигурацию
config = pulumi.Config()

# Читаем публичный ключ SSH. 
# В terraform.tfvars был путь ~/.ssh/id_rsa.pub. 
# Pulumi не умеет раскрывать ~ автоматически, поэтому используем os.path.expanduser
ssh_key_path = os.path.expanduser("~/.ssh/id_rsa.pub")
with open(ssh_key_path, 'r') as f:
    ssh_key = f.read().strip()

# Используем существующую сеть 'default'
default_network = yandex.get_vpc_network(name="default")

# Создаем подсеть (так же как в Terraform)
subnet = yandex.VpcSubnet("lab-subnet-pulumi",
    name="lab-subnet-pulumi",
    zone="ru-central1-a",
    network_id=default_network.id,
    v4_cidr_blocks=["192.168.20.0/24"] # Используем другой CIDR, чтобы не конфликтовать если что
)

# Получаем последний образ Ubuntu
ubuntu_image = yandex.get_compute_image(family="ubuntu-2204-lts")

# Создаем виртуальную машину
vm = yandex.ComputeInstance("lab-vm-pulumi",
    name="lab-vm-pulumi",
    platform_id="standard-v2",
    zone="ru-central1-a",
    resources=yandex.ComputeInstanceResourcesArgs(
        cores=2,
        memory=1,
        core_fraction=20,
    ),
    boot_disk=yandex.ComputeInstanceBootDiskArgs(
        initialize_params=yandex.ComputeInstanceBootDiskInitializeParamsArgs(
            image_id=ubuntu_image.id,
            size=10,
        ),
    ),
    network_interfaces=[yandex.ComputeInstanceNetworkInterfaceArgs(
        subnet_id=subnet.id,
        nat=True,
    )],
    metadata={
        "ssh-keys": f"ubuntu:{ssh_key}",
    },
    scheduling_policy=yandex.ComputeInstanceSchedulingPolicyArgs(
        preemptible=True,
    )
)

# Экспортируем данные
pulumi.export("vm_public_ip", vm.network_interfaces[0].nat_ip_address)
pulumi.export("ssh_connection_command", vm.network_interfaces[0].nat_ip_address.apply(
    lambda ip: f"ssh ubuntu@{ip}"
))
