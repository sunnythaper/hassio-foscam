FROM %%BASE_IMAGE%%

ENV LANG C.UTF-8

# Setup base
RUN apk add --no-cache tzdata jq curl mosquitto-clients

# Copy data for add-on
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
