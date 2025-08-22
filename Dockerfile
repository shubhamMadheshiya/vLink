# Use Tomcat 10 with JDK 21 as base image
FROM tomcat:10.1-jdk21

LABEL project="vLink" \
      author="Shubham" \
      description="vLink application packaged with Tomcat 10"

# Set working directory
WORKDIR /usr/local/tomcat/

# Clean default Tomcat apps
RUN rm -rf webapps/*

# Copy WAR file into ROOT context
COPY target/vprofile-v2.war webapps/ROOT.war

# Expose Tomcat port
EXPOSE 8080

# Run Tomcat
CMD ["catalina.sh", "run"]
