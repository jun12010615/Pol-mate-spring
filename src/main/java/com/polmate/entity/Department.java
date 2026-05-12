package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "departments")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class Department {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "dept_id")
    private Integer deptId;

    @Column(name = "dept_name")
    private String deptName;

    @Column(name = "org_name")
    private String orgName;
}
