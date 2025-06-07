FROM public.ecr.aws/lambda/python:3.11

# Install system dependencies for PostgreSQL and other requirements
RUN yum update -y && \
    yum install -y gcc postgresql-devel && \
    yum clean all

# Copy all application code
COPY . ${LAMBDA_TASK_ROOT}

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install dependencies from all function directories if they exist
# RUN find ${LAMBDA_TASK_ROOT} -name "requirements.txt" -exec pip install --no-cache-dir -r {} \; 2>/dev/null || true

# Default command (will be overridden by Terraform's image_config.command)
CMD ["generate_transcript.handler.handler"]
