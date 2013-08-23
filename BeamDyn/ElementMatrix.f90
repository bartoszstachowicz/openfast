   SUBROUTINE ElementMatrix(Nuu0,Nuuu,Nrr0,Nrrr,hhp,Stif0,Jac,&
                            &w,node_elem,nelem,norder,dof_node,elk,elf)

   REAL(ReKi),INTENT(IN)::Nuu0(:),Nuuu(:),Nrr0(:),Nrrr(:)
   REAL(ReKi),INTENT(IN)::hhp(:,:),Stif0(:,:,:),Jac
   REAL(ReKi),INTENT(IN)::w(:)
   INTEGER,INTENT(IN)::node_elem,nelem,norder,dof_node

   REAL(ReKi),INTENT(OUT)::elk(:,:),elf(:)      

   REAL(ReKi),ALLOCATABLE::Fc_elem(:,:),Fd_elem(:,:),Oe_elem(:,:,:)
   REAL(ReKi),ALLOCATABLE::Pe_elem(:,:,:),Qe_elem(:,:,:),Se_elem(:,:,:)
   REAL(ReKi)::E10(3),RR0(3,3),kapa(3),E1(3),Stif(6,6),cet
   REAL(ReKi)::Fc(6),Fd(6),Oe(6,6),Pe(6,6),Qe(6,6)

   INTEGER::i,j,k,m,n,temp_id1,temp_id2
      

   ALLOCATE(Fc_elem(dof_node,node_elem),STAT = allo_stat)
   IF(allo_stat/=0) GOTO 9999
   Fc_elem = ZERO
   
   ALLOCATE(Fd_elem(dof_node,node_elem),STAT = allo_stat)
   IF(allo_stat/=0) GOTO 9999
   Fd_elem = ZERO
   
   ALLOCATE(Oe_elem(dof_node,dof_node,node_elem),STAT = allo_stat)
   IF(allo_stat/=0) GOTO 9999
   Oe_elem = ZERO
   
   ALLOCATE(Pe_elem(dof_node,dof_node,node_elem),STAT = allo_stat)
   IF(allo_stat/=0) GOTO 9999
   Pe_elem = ZERO
   
   ALLOCATE(Qe_elem(dof_node,dof_node,node_elem),STAT = allo_stat)
   IF(allo_stat/=0) GOTO 9999
   Qe_elem = ZERO
   
   ALLOCATE(Se_elem(dof_node,dof_node,node_elem),STAT = allo_stat)
   IF(allo_stat/=0) GOTO 9999
   Se_elem = ZERO

   DO i=1,node_elem
       E10 = ZERO
       E1 = ZERO
       RR0 = ZERO
       kapa = ZERO
       Fc = ZERO
       Fd = ZERO
       Oe = ZERO
       Pe = ZERO
       Qe = ZERO
       Stif = ZERO
       cet = ZERO
       CALL NodalDataAt0(node_elem,nelem,norder,dof_node,i,hhp,Nuu0,E10)
       CALL NodalData(Nuuu,Nrrr,Nuu0,Nrr0,E10,hhp,Stif0,&
                      &node_elem,nelem,i,norder,dof_node,&
                      &E1,RR0,kapa,Stif,cet)
       CALL ElasticForce(E1,RR0,kapa,Stif,cet,Fc,Fd,Oe,Pe,Qe)
       Fc_elem(1:6,i) = Fc(1:6)
       Fd_elem(1:6,i) = Fd(1:6)
       Oe_elem(1:6,1:6,i) = Oe(1:6,1:6)
       Pe_elem(1:6,1:6,i) = Pe(1:6,1:6)
       Qe_elem(1:6,1:6,i) = Qe(1:6,1:6)
       Se_elem(1:6,1:6,i) = Stif(1:6,1:6)
   ENDDO

   DO i=1,node_elem
       DO j=1,6
           temp_id1 = (i-1)*dof_node+j
           DO k=1,6
               temp_id2 = (i-1)*dof_node+k
               elk(temp_id1,temp_id2) = w(i)*Qe_elem(i,j,k)*Jac
           ENDDO
       ENDDO
   ENDDO

   DO i=1,node_elem
       DO j=1,node_elem
           DO k=1,6
               temp_id1=(i-1)*dof_node+k
               DO m=1,6
                   temp_id2=(i-1)*dof_node+m
                   elk(temp_id1,temp_id2)=elk(temp_id1,temp_id2)+w(i)*Pe_elem(i,k,m)*hhp(j,i)
                   elk(temp_id1,temp_id2)=elk(temp_id1,temp_id2)+w(j)*Oe_elem(j,k,m)*hhp(i,j)
               ENDDO
           ENDDO
       ENDDO
   ENDDO

   DO i=1,node_elem
       DO j=1,node_elem
           DO k=1,6
               temp_id1=(i-1)*dof_node+k
               DO m=1,6
                   temp_id2=(j-1)*dof_node+m
                   DO n=1,node_elem
                       elk(temp_id1,temp_id2)=elk(temp_id1,temp_id2)+w(n)*hhp(i,n)*Se_elem(n,k,m)*hhp(j,n)/Jac
                   ENDDO
               ENDDO
           ENDDO
       ENDDO
   ENDDO

   DO i=1,node_elem
       DO j=1,6
           temp_id1 = (i-1)*dof_node+j
           elf(temp_id1) = -w(i)*Fd_elem(i,j)*Jac
           DO m=1,node_elem
              elf(temp_id1) = elf(temp_id1)-w(m)*hhp(i,m)*Fc_elem(m,j)
           ENDDO
       ENDDO
   ENDDO
   
   9999 IF(allo_stat/=0) THEN
            IF(ALLOCATED(Fc_elem)) DEALLOCATE(Fc_elem)
            IF(ALLOCATED(Fd_elem)) DEALLOCATE(Fd_elem)
            IF(ALLOCATED(Oe_elem)) DEALLOCATE(Oe_elem)
            IF(ALLOCATED(Pe_elem)) DEALLOCATE(Pe_elem)
            IF(ALLOCATED(Qe_elem)) DEALLOCATE(Qe_elem)
            IF(ALLOCATED(Se_elem)) DEALLOCATE(Se_elem)
        ENDIF

   END SUBROUTINE ElementMatrix