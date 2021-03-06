FROM prom/prometheus

COPY ./prometheus.yml /etc/prometheus/prometheus.yml

CMD /usr/local/bin/prometheus
