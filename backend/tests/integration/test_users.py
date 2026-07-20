"""Integration tests for user management endpoints."""

from io import BytesIO

import pytest
from fastapi.testclient import TestClient

from src.domain.enums import Role


@pytest.fixture
def auth_headers(director_token):
    return {"Authorization": f"Bearer {director_token}"}


@pytest.fixture
def professor_headers(professor_token):
    return {"Authorization": f"Bearer {professor_token}"}


def test_list_school_users_as_director(test_client: TestClient, director, sample_school, auth_headers):
    response = test_client.get(f"/api/v1/users/school/{sample_school.id}", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    usernames = {u["username"] for u in data}
    assert director.username in usernames


def test_list_section_users_as_professor(test_client, professor, sample_section, professor_headers):
    response = test_client.get(
        f"/api/v1/users/section/{sample_section.id}", headers=professor_headers
    )
    assert response.status_code == 200


def test_create_user_only_director(test_client, sample_school, auth_headers):
    payload = {
        "username": "new_user",
        "email": "new_user@battlegraf.local",
        "full_name": "New User",
        "password": "password123",
        "role": "tutor",
        "school_id": str(sample_school.id),
    }
    response = test_client.post("/api/v1/users", json=payload, headers=auth_headers)
    assert response.status_code == 201
    assert response.json()["role"] == "tutor"


def test_create_user_rejected_for_professor(test_client, sample_school, professor_headers):
    payload = {
        "username": "rejected_user",
        "email": "rejected@battlegraf.local",
        "full_name": "Rejected User",
        "password": "password123",
        "role": "tutor",
        "school_id": str(sample_school.id),
    }
    response = test_client.post("/api/v1/users", json=payload, headers=professor_headers)
    assert response.status_code == 403


def test_create_staff_professor(test_client, sample_school, auth_headers):
    payload = {
        "username": "professor_staff",
        "email": "professor_staff@battlegraf.local",
        "full_name": "Professor Staff",
        "password": "password123",
        "role": "professor",
    }
    response = test_client.post("/api/v1/users/staff", json=payload, headers=auth_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["role"] == "professor"
    assert data["school_id"] == str(sample_school.id)


def test_create_staff_invalid_role(test_client, sample_school, auth_headers):
    payload = {
        "username": "director_staff",
        "email": "director_staff@battlegraf.local",
        "full_name": "Director Staff",
        "password": "password123",
        "role": "director",
    }
    response = test_client.post("/api/v1/users/staff", json=payload, headers=auth_headers)
    assert response.status_code == 400


def test_bulk_create_students_csv(test_client, sample_school, sample_section, auth_headers):
    csv_content = "username,full_name,password\nstudent1,Student One,pass123\nstudent2,Student Two,pass456"
    file = BytesIO(csv_content.encode("utf-8"))
    response = test_client.post(
        f"/api/v1/users/{sample_school.id}/students/csv?section_id={sample_section.id}",
        files={"file": ("students.csv", file, "text/csv")},
        headers=auth_headers,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["created"] == 2
    assert data["errors"] == []


def test_bulk_create_students_csv_existing_username(test_client, sample_school, sample_section, auth_headers):
    csv_content = "username,full_name,password\nstudent1,Student One,pass123"
    file = BytesIO(csv_content.encode("utf-8"))
    response = test_client.post(
        f"/api/v1/users/{sample_school.id}/students/csv?section_id={sample_section.id}",
        files={"file": ("students.csv", file, "text/csv")},
        headers=auth_headers,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["created"] == 1

    response = test_client.post(
        f"/api/v1/users/{sample_school.id}/students/csv?section_id={sample_section.id}",
        files={"file": ("students.csv", file, "text/csv")},
        headers=auth_headers,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["created"] == 0
    assert any("student1" in error["detail"] for error in data["errors"])


def test_bulk_create_students_csv_wrong_section(test_client, sample_school, auth_headers):
    import uuid

    csv_content = "username,full_name,password\nstudent3,Student Three,pass789"
    file = BytesIO(csv_content.encode("utf-8"))
    response = test_client.post(
        f"/api/v1/users/{sample_school.id}/students/csv?section_id={uuid.uuid4()}",
        files={"file": ("students.csv", file, "text/csv")},
        headers=auth_headers,
    )
    assert response.status_code == 404


def test_bulk_create_students_csv_invalid_headers(test_client, sample_school, sample_section, auth_headers):
    csv_content = "wrong,header,here\nstudent1,Student One,pass123"
    file = BytesIO(csv_content.encode("utf-8"))
    response = test_client.post(
        f"/api/v1/users/{sample_school.id}/students/csv?section_id={sample_section.id}",
        files={"file": ("students.csv", file, "text/csv")},
        headers=auth_headers,
    )
    assert response.status_code == 400
