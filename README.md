# CloudFlare autopilot pattern

*Automatically update a Cloudflare DNS when a containerized service's IPs change*

### DNS updates

In a container-native project, we need to balance the desire for ephemeral infrastructure with the requirement to provide a predictable load-balanced interface with the outside world. By updating DNS records for a domain based on changes in the discovery service, we can make sure our users can reach the load-balancer for our project at all times.

This repo uses [Containerbuddy](https://github.com/joyent/containerbuddy) to listen for changes to the external load balancer tier and make API calls to [Cloudflare](https://www.cloudflare.com) to update DNS records. The updater application is a simple bash script (`./update-dns.sh`) that's triggered by the Containerbuddy `onChange` handler.


### Running the example

In the `example` directory is a simple application demonstrating how this works. In this application, Nginx is serving as a front-end web server that serves a static file. The Nginx nodes register themselves with Consul as they come online, and the Cloudflare application is configured with an `onChange` handler that makes API calls to the Cloudflare API, causing the A-records associated with the project to be updated.

Running this example on your own requires that you have a Cloudflare account and a domain that you've allowed Cloudflare to reverse proxy. Note that if you just want to try it out without actually updating your DNS records you can go through the whole process of getting Cloudflare in front of your site (on their free tier) and so long as you don't update your nameservers with your registrar there will be no actual changes to the DNS records seen by the rest of the world. Once you're ready:

1. [Get a Joyent account](https://my.joyent.com/landing/signup/) and [add your SSH key](https://docs.joyent.com/public-cloud/getting-started).
1. Install the [Docker Toolbox](https://docs.docker.com/installation/mac/) (including `docker` and `docker-compose`) on your laptop or other environment, as well as the [Joyent CloudAPI CLI tools](https://apidocs.joyent.com/cloudapi/#getting-started) (including the `smartdc` and `json` tools)
1. Have your Cloudflare API key handy.
1. [Configure Docker and Docker Compose for use with Joyent](https://docs.joyent.com/public-cloud/api-access/docker):

```bash
curl -O https://raw.githubusercontent.com/joyent/sdc-docker/master/tools/sdc-docker-setup.sh && chmod +x sdc-docker-setup.sh
./sdc-docker-setup.sh -k us-east-1.api.joyent.com <ACCOUNT> ~/.ssh/<PRIVATE_KEY_FILE>
```

At this point you can run the example on Triton:

```bash
cd ./examples
make .env
./start.sh

```

or in your local Docker environment:

```bash
cd ./examples
make
# at this point you'll be asked to fill in the values of the .env
# file and make will exit, so we need to run it again
make
./start.sh -f docker-compose-local.yml

```

The `.env` file that's created will need to be filled in with the values describe below:

```
CF_API_KEY=<your Cloudflare API key>
CF_AUTH_EMAIL=<the email address associated with your Cloudflare account>
CF_ROOT_DOMAIN=<the root domain you want to manage. ex. example.com>
SERVICE=nginx <the name of the service you want to monitor>
RECORD=<the A-record you want to manage. ex. my.example.com>
TTL=600 <the DNS TTL you want>
```

The Consul UI will launch and you'll see the Nginx node appear. The script will also open your Cloudflare control panel at https://www.cloudflare.com/a/dns/example.com (using your own domain, of course) and then you'll see the domain or subdomain you provided in the `.env` file.

Let's scale up the number of `nginx` nodes:

```bash
docker-compose scale nginx=3
```

As the nodes launch and register themselves with Consul, you'll see them appear in the Consul UI. You'll also see the A records in your Cloudflare console update.
