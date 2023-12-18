FROM python:3.12

WORKDIR /app

COPY Pipfile* .

COPY src .

RUN pip install pipenv

RUN pipenv install --system --deploy --ignore-pipfile

CMD ["uvicorn", "main:app", "--proxy-headers", "--host", "0.0.0.0", "--port", "8080"]