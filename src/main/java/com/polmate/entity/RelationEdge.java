package com.polmate.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "relation_edges")
@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class RelationEdge {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "edge_id")
    private Integer edgeId;

    @Column(name = "case_id")
    private String caseId;

    @Column(name = "src_person_id")
    private String srcPersonId;

    @Column(name = "dst_person_id")
    private String dstPersonId;

    @Column(name = "rel_type")
    private String relType;

    @Column(name = "status")
    private String status;

    @Column(name = "context")
    private String context;
}
