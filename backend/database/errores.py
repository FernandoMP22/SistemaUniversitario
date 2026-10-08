from fastapi import HTTPException


def traducir_error_database(error):
    codigo = error.orig.sqlstate

    if codigo == "23505":
        return HTTPException(
            status_code=409,
            detail="Ya existe un registro con esos datos únicos.",
        )

    if codigo == "23503":
        return HTTPException(
            status_code=409,
            detail=(
                "La operación utiliza una referencia inexistente "
                "o afecta un registro relacionado."
            ),
        )

    if codigo == "23514":
        return HTTPException(
            status_code=400,
            detail="La operación incumple una regla de la base de datos.",
        )

    if codigo == "23502":
        return HTTPException(
            status_code=400,
            detail="Falta un dato obligatorio.",
        )

    if codigo == "40001":
        return HTTPException(
            status_code=503,
            detail=(
                "No se pudo completar la operación por conflictos "
                "simultáneos. Intenta nuevamente."
            ),
        )

    return HTTPException(
        status_code=500,
        detail="No se pudo completar la operación en la base de datos.",
    )