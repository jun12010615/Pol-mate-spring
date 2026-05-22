package com.polmate.annotation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface LogAccess {
    String type();       // "CASE_VIEW", "TRANSCRIPT_VIEW", "BOARD_VIEW"
    String nameKey() default ""; // result Map에서 target_name으로 쓸 키
}
