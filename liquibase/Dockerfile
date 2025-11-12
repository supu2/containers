# Use Alpine Linux as base image for smaller size
FROM liquibase/liquibase:5.0.1
USER root
RUN chown liquibase:root /liquibase && \
    chmod g+rx /liquibase
USER liquibase:liquibase
RUN lpm add postgresql --global
