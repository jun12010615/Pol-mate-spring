package com.polmate;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync
public class PolmateApplication {

    public static void main(String[] args) {
        SpringApplication.run(PolmateApplication.class, args);
    }
}
