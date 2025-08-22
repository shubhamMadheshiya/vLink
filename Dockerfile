FROM tomcat:10-jdk21
LABEL "Project"="vLink"
LABEL "Author"="Shubham"

RUN rm -rf /usr/local/tomcat/webapps/*
COPY target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080
WORKDIR /usr/local/tomcat/
CMD ["catalina.sh", "run"]