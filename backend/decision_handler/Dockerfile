# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /usr/src/app

# Install any needed packages specified in requirements.txt
# You should have Flask listed in a requirements.txt file
COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt --no-cache-dir


# Copy the current directory contents into the container at /usr/src/app
COPY . .

# Make port 5000 available to the world outside this container
EXPOSE 5001

# Define environment variable
ENV FLASK_APP=app.py

# CMD [ "python3", "-m" , "flask", "run", "--host=0.0.0.0"]

# Run app.py when the container launches
# CMD ["flask", "run", "--host=0.0.0.0", "--port=5001"]
CMD ["python", "app.py"]