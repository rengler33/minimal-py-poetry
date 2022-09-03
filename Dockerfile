# #### BASE-PYTHON ####
FROM python:3.10-slim as base-python

# PYTHONPYCACHEPREFIX is used to store bytecode outside mounted directory
# poetry will install into an isolated directory via POETRY_HOME
# so that poetry's dependencies do not conflict
# poetry will use VIRTUAL_ENV to check if it should install into there instead (so it does)
ENV PYTHONUNBUFFERED=1 \
    PYTHONPYCACHEPREFIX="/tmp/.cache/pycache/" \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    POETRY_VERSION=1.2.0 \
    POETRY_HOME="/tmp/poetry" \
    POETRY_NO_INTERACTION=1 \
    VIRTUAL_ENV="/venvs/venv"


ENV PATH="$POETRY_HOME/bin:$VIRTUAL_ENV/bin:$PATH"



# #### BASE-IMAGE #### #
# has poetry and non-dev python requirements installed
FROM base-python as base-build

# install poetry and other dev dependencies
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    curl \
    build-essential \
    git
# install poetry (with new installer)
RUN curl -sSL https://install.python-poetry.org | python3 -

# create virtual environment that will serve as base for all other installs
RUN python3 -m venv $VIRTUAL_ENV

COPY ./poetry.lock ./pyproject.toml /application_root/
WORKDIR /application_root

# VIRTUAL_ENV is used in base-python stage to specify a venv location that is put on path (with /bin)
# poetry therefore thinks it needs to install there instead of create new environment

# mount cache helps prevent re-downloading of ALL deps when only one dep changed
# TODO haven't verified that this works as expected

# install [tool.poetry.dependencies] without dev dependencies or application
RUN --mount=type=cache,target=/home/.cache/pypoetry/cache \
    --mount=type=cache,target=/home/.cache/pypoetry/artifacts \
    poetry install --no-root --only main



# #### DEVELOPMENT-IMAGE #### #
FROM base-build as development-image

# install all dependencies
# --no-root installs only the dependencies, for better build caching
RUN --mount=type=cache,target=/home/.cache/pypoetry/cache \
    --mount=type=cache,target=/home/.cache/pypoetry/artifacts \
    poetry install --no-root

COPY . /application_root/

# followed by another install for the app code
RUN poetry install --only main

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--reload", "--host", "0.0.0.0"]



# #### PRE-PRODUCTION-IMAGE #### #
# uses poetry to install the application (the project's package)
FROM base-build as pre-production-build
# install for app code (dependencies already installed)
# create files poetry needs to see in order "install" (symlink) the app
RUN mkdir /application_root/app
RUN touch /application_root/app/__init__.py && touch /application_root/README.md
RUN poetry install --only main



# #### PRODUCTION-IMAGE #### #
# uses a smaller version of python image and doesn't need poetry
# instead copies venv from pre-production-build
FROM python:3.10-alpine as production-image

ENV VIRTUAL_ENV="/venvs/venv"
# put the virtual env at front of path so it doesn't need to be activated
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# assumes base-build created venv in a folder in this location
COPY --from=pre-production-build /venvs /venvs

# copies only application code required for production
COPY ./app /application_root/app/
WORKDIR /application_root/app

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0"]
