# #### BASE-PYTHON-POETRY ####
# has python and poetry installed
# would push this part to a registry
FROM python:3.9 as base-python-poetry

# poetry will use VIRTUAL_ENV to check if it should install into there instead (so it does)
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    POETRY_VERSION=1.1.13 \
    POETRY_HOME="/opt/poetry" \
    PYTHONPATH=/application_root \
    VIRTUAL_ENV="/venvs/venv"

ENV PATH="$POETRY_HOME/bin:$VIRTUAL_ENV/bin:$PATH"

# new installer for poetry, "install-poetry.py" instead of old "get-poetry.py"
# https://python-poetry.org/docs/master/#installing-with-the-official-installer
RUN curl -sSL https://install.python-poetry.org | python3 -

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

# install [tool.poetry.dependencies]
RUN poetry install --no-interaction --no-root --no-dev


# #### DEVELOPMENT-IMAGE #### #
FROM base-image as development-image

# install [tool.poetry.dev-dependencies]
RUN poetry install --no-interaction --no-root

COPY . /application_root/
# alternatively, you can set a volume mount to /application_root/

CMD ["/bin/bash"]


# #### PRODUCTION-IMAGE #### #
# uses a smaller version of python image and doesn't need poetry
# instead copies venv from base-image
FROM python:3.9-slim as production-image

WORKDIR /application_root
ENV PYTHONPATH=/application_root \
    VIRTUAL_ENV="/venvs/venv"

# put the virtual env at front of path so it doesn't need to be activated
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# assumes base-image created venv in a folder in this location
COPY --from=base-image /venvs /venvs

# copies only application code required for production
COPY ./app /application_root/app/

CMD ["/bin/bash"]
