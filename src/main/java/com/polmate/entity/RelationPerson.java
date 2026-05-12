package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "relation_persons")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class RelationPerson {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "person_id")
    private Integer personId;

    @Column(name = "case_id")
    private String caseId;

    @Column(name = "person_name")
    private String personName;

    @Column(name = "role")
    private String role;

    @Column(name = "memo")
    private String memo;
}
