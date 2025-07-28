from utilities.helpers import generate_readings_id
from model.readingsinfo import ReadingsInfo

def create_reading(db, data):
    new_id = generate_readings_id(db)
    
    new_reading = ReadingsInfo(
        ReadingsID=new_id,
        Title=data["Title"],
        Author=data["Author"],
        Description=data["Description"],
        EstimatedMinutes=data["EstimatedMinutes"],
        XPValue=data["XPValue"],
        Rating=data["Rating"],
        ModuleTypeID=data["ModuleTypeID"]
    )
    db.add(new_reading)
    db.commit()
    db.refresh(new_reading)
    return new_reading
