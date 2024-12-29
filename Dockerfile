FROM alpine:3.19.4
HEALTHCHECK NONE
ENTRYPOINT ["/letsencrypt-routeros.bash"]
RUN apk add --no-cache bash~=5 openssh~=9; id user || adduser -D user
COPY letsencrypt-routeros.bash /letsencrypt-routeros.bash
USER user
