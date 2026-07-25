FROM node:20-alpine

RUN curl -L https://getfoundry.sh/install | bash
ENV PATH="/root/.foundry/bin:${PATH}"

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY . .

CMD ["sh", "-c", "while true; do node index.js; sleep 5; done"]
