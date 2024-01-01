FROM python:3.12-slim as build

COPY pyproject.toml poetry.lock ./

RUN pip install --no-cache-dir poetry==1.7 && poetry install --no-root --no-ansi --no-interaction --no-cache \
&& poetry export -f requirements.txt -o requirements.txt

FROM python:3.12-slim

WORKDIR /app

COPY --from=build requirements.txt .

RUN set -ex \
&& addgroup --system --gid 1001 appgroup \
&& adduser --system --uid 1001 --gid 1001 --no-create-home appuser \
&& apt-get update \
&& apt-get upgrade -y \
&& pip install --no-cache-dir -r requirements.txt \
&& apt-get autoremove -y \
&& apt-get clean -y \
&& rm -rf /var/lib/apt/lists/*

COPY src .

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]

USER appuser