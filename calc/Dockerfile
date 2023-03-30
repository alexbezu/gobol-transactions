FROM golang:1.17 as build
WORKDIR /app/
COPY go.mod go.sum /app/
RUN go mod download -x
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /transactions/calc calc/calc.go

FROM scratch as scratch
WORKDIR /
ENV DBHOST="db" \
    DBPORT="3322" \
    TN3270DIR="/app/transactions"
COPY --from=build /transactions/calc /transactions/calc
ENTRYPOINT ["/transactions/calc"]