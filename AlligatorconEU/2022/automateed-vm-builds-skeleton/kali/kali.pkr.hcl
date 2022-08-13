variable "vault_pass" {
  type    = string
  default = "${env("VAULT_PASS")}"
}

variable "vm_output_directory" {
  type    = string
  default = "${env("VM_OUTPUT_DIRECTORY")}"
}

source "vmware-iso" "kali" {
  iso_url          = "http://cdimage.kali.org/kali-2022.2/kali-linux-2022.2-installer-netinst-amd64.iso"
  iso_checksum     = "sha256:d7444e8afb74b9b3c8c8be9f15fb64eddc0414960d9e2691c465740d58573eff"
  disk_size        = 80000
  guest_os_type    = "debian11-64"
  format           = "vmx"
  boot_command     = [
    "<wait><ESC><wait><ESC><wait><ESC><wait><ESC><wait><ESC><wait><ESC><wait><ESC><wait><ESC><wait><ESC><wait>", 
    # make sure u can enter boot command
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ", 
    # perks of packer: no need to hassle with device mounting etc, just download preseed file from host
    "console-setup/ask_detect=false ",
    "console-setup/layoutcode=de ",
    "console-setup/modelcode=pc105 ",
    "kbd-chooser/method=de ",
    "locale=en_US ",
    "console-keymaps-at/keymap=de ",
    "keyboard-configuration/xkb-keymap=de ",
    "keyboard-configuration/layout=Germany ",
    "keyboard-configuration/variant=Germany ",
    "debian-installer=en_US ",
    "<enter>"
    ]
  shutdown_command = "poweroff"
  http_content     = {
    "/preseed.cfg" = file("preseed.cfg")
  }
  snapshot_name    = "clean install"
  # creates snapshot after vm-build is done
  output_directory = "${var.vm_output_directory}"
  display_name     = "kali"
  headless         = true
  vm_name          = "Kali"
  cpus             = 4
  cores            = 4
  # single socket with four cores
  memory           = 8192  
  disk_type_id     = 0
  # growable, single file
  ssh_username     = "root"
  ssh_password     = "<password set in preseed file>"
  ssh_timeout      = "240m"
}

build {
  sources = ["source.vmware-vmx.kali"]

  provisioner "shell" {
    inline = [
      "echo ${var.vault_pass} > /tmp/vault-secrets.txt"
      ]
  }

  provisioner "ansible-local" {
    extra_arguments   = ["--vault-password-file", "/tmp/vault-secrets.txt"]
    inventory_file    = "./ansible/hosts.yml"
    playbook_dir      = "./ansible"
    playbook_file     = "./ansible/site.yml"
    staging_directory = "/etc/ansible"
  }

  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "${var.vm_output_directory}/${formatdate("YYYY-MM-DD", timestamp())}-${source.name}_{{.ChecksumType}}.txt"
  }

  post-processor "compress" {
    compression_level = 7
    output            = "${var.vm_output_directory}/${formatdate("YYYY-MM-DD", timestamp())}-${source.name}.zip"
  }
}
