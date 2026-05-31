FROM intersystemsdc/irishealth-community:latest

WORKDIR /home/irisowner/dev

ARG TESTS=0
ARG MODULE="claim-audit-ai"
ARG NAMESPACE="INTEROP"

ENV IRISUSERNAME ""
ENV IRISPASSWORD ""
ENV IRISNAMESPACE $NAMESPACE
ENV PYTHON_PATH=/usr/irissys/bin/
ENV PYTHONPATH="/usr/irissys/lib/python"
ENV PATH "/usr/irissys/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/irisowner/bin"

# Copy requirements and install CPU-optimized PyTorch and remaining dependencies
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} requirements.txt /home/irisowner/dev/requirements.txt

# 1. Install CPU-only PyTorch first (drastically reduces download size from 2.5GB to ~80MB)
# 2. Install remaining version-controlled packages
RUN python3 -m venv "/home/irisowner/.venvs/mcp-tools" && \
    "/home/irisowner/.venvs/mcp-tools/bin/python" -m pip install --upgrade pip && \
    "/home/irisowner/.venvs/mcp-tools/bin/python" -m pip install torch>=2.1.0 --index-url https://download.pytorch.org/whl/cpu --break-system-packages --target /usr/irissys/mgr/python && \
    "/home/irisowner/.venvs/mcp-tools/bin/python" -m pip install -r /home/irisowner/dev/requirements.txt --break-system-packages --target /usr/irissys/mgr/python

# Copy the rest of the codebase files for compilation
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} . /home/irisowner/dev

# Copy runtime init script for docker-entrypoint (first-start only)
COPY --chmod=755 --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} init_iris.sh /docker-entrypoint-initdb.d/

# Start IRIS, execute build script, and shut down
RUN iris start IRIS && \
    iris session IRIS < iris.script && \
    iris stop IRIS quietly
