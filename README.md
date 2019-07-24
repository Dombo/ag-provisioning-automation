# What and how?

* A&G Snr. DevOps interview test

* Provide some explanation of what I'm doing in the dockerfile before they get concerned I guess?

# What do you need to get started?

* Docker (preferably a *nix host - windows incompatibilities not tested)
* SSH public key located at ~/.ssh/id_rsa
* AWS credentials located at ~/.aws/*
* Sourcing the right profile and setting the region?

# Running the example

```bash
> build the docker image
> boot it as a quick test
> run init via the container
> run apply via the container

```

Cleaning up

```bash
> run destroy via the container
```

# Housekeeping / Troubleshooting

----

Notes 


# Primary example probably needs

* ASG
* LaunchConfig
    * AMI
    * SSH Key loading
    * Provisioning
    * EC2 metadata binding
* ELB
* VPC
* Subnet
* SecurityGroup

# Alternate examples

* Build an AMI to save on spin up time
* Load balance at the DNS layer if you don't require multi-AZ resiliency / cost footprint declines