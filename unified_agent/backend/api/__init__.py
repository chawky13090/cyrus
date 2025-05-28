from flask import Blueprint

api_bp = Blueprint('api', __name__)

# Import routes to register them
from . import chat_routes 
from . import tool_routes # Add this line
