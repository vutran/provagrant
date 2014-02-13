# ProVagrant

Provision a server with Vagrant. 

# Before doing anything, please install Vagrant and VirtualBox

- [Vagrant](http://www.vagrantup.com/)
- [VirtualBox](https://www.virtualbox.org/)

# Initialize Vagrant

Within the Terminal, create a new project folder and initialize Vagrant:

	mkdir MyVagrantProject && cd MyVagrantProject

Initialize a new VagrantFile (precise32)

	vagrant init precise32 http://files.vagrantup.com/precise32.box

Within the Terminal, start the Vagrant box:

	vagrant up

# Provision the Environment

`bootstrap.sh` will be executed during the the setup of the virtual machine. Please refer to `bootstrap.sh` for more information.

# Credits

* [Venison](https://github.com/tjstein/venison)