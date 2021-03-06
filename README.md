## Running the setup

1. Create a VM with the [`build.sh`](./build.sh) script
2. Make sure to have `j2` setup
```sh
$ python3 -m pip install j2cli
$ j2 --version
```
3. Setup the prometheus config file using
```sh
$ server=<name of the remote host> j2 prometheus.yml.j2 > prometheus.yml
```
4. Make sure the build script runs
5. Start the prometheus container to scrape for the metrics
```sh
docker run --rm -it -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml -p 9090:9090 prom/prometheus
```
