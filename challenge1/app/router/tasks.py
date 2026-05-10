from fastapi import APIRouter, Depends, HTTPException, Query                                     
from sqlalchemy.orm import Session                                                               
from typing import Optional                                                                      

import models
import schemas
import boto3
import os
import json
from database import get_db

# ルーターの上部に追加
_eb = boto3.client("events", region_name=os.getenv("AWS_REGION", "ap-northeast-1"))
_EVENT_BUS = os.getenv("EVENT_BUS_NAME", "task-events")

router = APIRouter()


@router.get("", response_model=list[schemas.TaskResponse])
def list_tasks(
    status: Optional[schemas.TaskStatus] = Query(None),
    db: Session = Depends(get_db),
):
    query = db.query(models.Task)
    if status:
        query = query.filter(models.Task.status == status)
    return query.all()


@router.post("", response_model=schemas.TaskResponse, status_code=201)
def create_task(task_in: schemas.TaskInput, db: Session = Depends(get_db)):
    task = models.Task(**task_in.model_dump())
    db.add(task)
    db.commit()
    db.refresh(task)

    # EventBridge にイベント送信
    _eb.put_events(Entries=[{
        "Source": "api.tasks",
        "DetailType": "TaskCreated",
        "Detail": json.dumps({
            "task_id": task.id,
            "title": task.title,
            "status": task.status,
        }),
        "EventBusName": _EVENT_BUS,
    }])

    return task


@router.get("/{task_id}", response_model=schemas.TaskResponse)
def get_task(task_id: int, db: Session = Depends(get_db)):
    task = db.query(models.Task).filter(models.Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail={"message": "タスクが見つかりません"})
    return task


@router.put("/{task_id}", response_model=schemas.TaskResponse)
def update_task(task_id: int, task_in: schemas.TaskInput, db: Session = Depends(get_db)):
    task = db.query(models.Task).filter(models.Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail={"message": "タスクが見つかりません"})
    for key, value in task_in.model_dump().items():
        setattr(task, key, value)
    db.commit()
    db.refresh(task)
    return task


@router.delete("/{task_id}", status_code=204)
def delete_task(task_id: int, db: Session = Depends(get_db)):
    task = db.query(models.Task).filter(models.Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail={"message": "タスクが見つかりません"})
    db.delete(task)
    db.commit()
