# #### BASE-PYTHON-POETRY ####
# has python and poetry installed
# would push this part to a registry
FROM python:3.10 as base-python-poetry

# poetry will install into an isolated directory via POETRY_HOME
# so that poetry's dependencies do not conflict
# poetry will use VIRTUAL_ENV to check if it should install into there instead (so it does)
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    POETRY_VERSION=1.2.0 \
    POETRY_HOME="/tmp/poetry" \
    POETRY_NO_INTERACTION=1 \
    VIRTUAL_ENV="/venvs/venv"

# new installer for poetry, "install-poetry.py" instead of old "get-poetry.py"
# https://python-poetry.org/docs/master/#installing-with-the-official-installer
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="$POETRY_HOME/bin:$VIRTUAL_ENV/bin:$PATH"

# create virtual environment that will serve as base for all other installs
RUN python3 -m venv $VIRTUAL_ENV



# #### BASE-IMAGE #### #
# has non-dev python requirements installed
# would actually pull from registry rather than base-python-poetry in same file
FROM base-python-poetry as base-image
WORKDIR /application_root

COPY ./poetry.lock ./pyproject.toml /application_root/

# VIRTUAL_ENV is used in base-python-poetry to specify a venv location that is put on path (with /bin)
# poetry therefore thinks it needs to install there instead of create new environment

# install [tool.poetry.dependencies] without dev dependencies or application
RUN poetry install --no-root --only main



# #### DEVELOPMENT-IMAGE #### #
FROM base-image as development-image

# install all dependencies
# --no-root installs only the dependencies, for better build caching
RUN poetry install --no-root

COPY . /application_root/
# will probably set a volume mount to /application_root/ for dev

# followed by another install for the app code
RUN poetry install --only main

CMD ["/bin/bash"]



# #### PRE-PRODUCTION-IMAGE #### #
# uses poetry to install the application (the project's package)
FROM base-image as pre-production-image
# install for app code (dependencies already installed)
# create files poetry needs to see in order "install" (symlink) the app
RUN mkdir /application_root/app
RUN touch /application_root/app/__init__.py && touch /application_root/README.md
RUN poetry install --only main



# #### PRODUCTION-IMAGE #### #
# uses a smaller version of python image and doesn't need poetry
# instead copies venv from base-image
FROM python:3.10-alpine as production-image

WORKDIR /application_root
ENV VIRTUAL_ENV="/venvs/venv"
# put the virtual env at front of path so it doesn't need to be activated
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# assumes base-image created venv in a folder in this location
COPY --from=pre-production-image /venvs /venvs

# copies only application code required for production
COPY ./app /application_root/app/

CMD ["/bin/sh"]
