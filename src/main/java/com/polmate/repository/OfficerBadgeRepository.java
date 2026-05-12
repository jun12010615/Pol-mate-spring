package com.polmate.repository;

import com.polmate.entity.OfficerBadge;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

public interface OfficerBadgeRepository extends JpaRepository<OfficerBadge, String> {

    Optional<OfficerBadge> findByBadgeNum(String badgeNum);

    @Modifying @Transactional
    @Query("UPDATE OfficerBadge o SET o.isUsed = 1 WHERE o.badgeNum = :badgeNum")
    int markUsed(@Param("badgeNum") String badgeNum);
}
