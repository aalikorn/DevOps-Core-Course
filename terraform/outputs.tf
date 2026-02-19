output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = yandex_compute_instance.lab_vm.network_interface.0.nat_ip_address
}

output "ssh_connection_command" {
  value = "ssh ubuntu@${yandex_compute_instance.lab_vm.network_interface.0.nat_ip_address}"
}