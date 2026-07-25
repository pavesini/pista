FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends curl bash ca-certificates && rm -rf /var/lib/apt/lists/*
RUN curl -L https://getfoundry.sh/install | bash
ENV PATH="/root/.foundry/bin:${PATH}"
RUN foundryup

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY . .
RUN chmod +x pause_tx.sh

CMD ["sh", "-c", "while true; do node index.js; sleep 10; done"]
