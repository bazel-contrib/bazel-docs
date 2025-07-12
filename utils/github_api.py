"""
GitHub API Module
Handles GitHub API interactions for monitoring repository changes
"""

import os
import logging
import requests
from typing import Dict, List, Optional
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

class GitHubAPI:
    """GitHub API wrapper for repository monitoring"""
    
    def __init__(self, token: str):
        """
        Initialize GitHub API client
        
        Args:
            token: GitHub API token
        """
        self.token = token
        self.base_url = "https://api.github.com"
        self.headers = {
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json'
        }
    
    def get_latest_commit(self, owner: str, repo: str, branch: str = 'master', 
                         path: Optional[str] = None) -> Optional[Dict]:
        """
        Get the latest commit for a repository or path
        
        Args:
            owner: Repository owner
            repo: Repository name
            branch: Branch name (default: master)
            path: Optional path to filter commits
            
        Returns:
            Dictionary with commit information or None if not found
        """
        try:
            url = f"{self.base_url}/repos/{owner}/{repo}/commits"
            params = {
                'sha': branch,
                'per_page': 1
            }
            
            if path:
                params['path'] = path
            
            response = requests.get(url, headers=self.headers, params=params)
            response.raise_for_status()
            
            commits = response.json()
            if not commits:
                return None
            
            commit = commits[0]
            return {
                'sha': commit['sha'],
                'message': commit['commit']['message'],
                'author': commit['commit']['author']['name'],
                'date': commit['commit']['author']['date'],
                'url': commit['html_url']
            }
            
        except requests.RequestException as e:
            logger.error(f"Failed to get latest commit: {e}")
            return None
    
    def get_commits_since(self, owner: str, repo: str, since_date: datetime, 
                         branch: str = 'master', path: Optional[str] = None) -> List[Dict]:
        """
        Get commits since a specific date
        
        Args:
            owner: Repository owner
            repo: Repository name
            since_date: Get commits since this date
            branch: Branch name (default: master)
            path: Optional path to filter commits
            
        Returns:
            List of commit dictionaries
        """
        try:
            url = f"{self.base_url}/repos/{owner}/{repo}/commits"
            params = {
                'sha': branch,
                'since': since_date.isoformat(),
                'per_page': 100
            }
            
            if path:
                params['path'] = path
            
            response = requests.get(url, headers=self.headers, params=params)
            response.raise_for_status()
            
            commits = response.json()
            return [
                {
                    'sha': commit['sha'],
                    'message': commit['commit']['message'],
                    'author': commit['commit']['author']['name'],
                    'date': commit['commit']['author']['date'],
                    'url': commit['html_url']
                }
                for commit in commits
            ]
            
        except requests.RequestException as e:
            logger.error(f"Failed to get commits since {since_date}: {e}")
            return []
    
    def get_file_content(self, owner: str, repo: str, path: str, 
                        branch: str = 'master') -> Optional[str]:
        """
        Get file content from repository
        
        Args:
            owner: Repository owner
            repo: Repository name
            path: File path
            branch: Branch name (default: master)
            
        Returns:
            File content as string or None if not found
        """
        try:
            url = f"{self.base_url}/repos/{owner}/{repo}/contents/{path}"
            params = {'ref': branch}
            
            response = requests.get(url, headers=self.headers, params=params)
            response.raise_for_status()
            
            content_data = response.json()
            if content_data.get('encoding') == 'base64':
                import base64
                content = base64.b64decode(content_data['content']).decode('utf-8')
                return content
            
            return content_data.get('content', '')
            
        except requests.RequestException as e:
            logger.error(f"Failed to get file content {path}: {e}")
            return None
    
    def get_repository_info(self, owner: str, repo: str) -> Optional[Dict]:
        """
        Get repository information
        
        Args:
            owner: Repository owner
            repo: Repository name
            
        Returns:
            Dictionary with repository information or None if not found
        """
        try:
            url = f"{self.base_url}/repos/{owner}/{repo}"
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            
            repo_data = response.json()
            return {
                'name': repo_data['name'],
                'full_name': repo_data['full_name'],
                'description': repo_data.get('description', ''),
                'html_url': repo_data['html_url'],
                'clone_url': repo_data['clone_url'],
                'default_branch': repo_data['default_branch'],
                'updated_at': repo_data['updated_at']
            }
            
        except requests.RequestException as e:
            logger.error(f"Failed to get repository info: {e}")
            return None
    
    def create_repository_dispatch(self, owner: str, repo: str, event_type: str, 
                                  client_payload: Optional[Dict] = None) -> bool:
        """
        Create a repository dispatch event
        
        Args:
            owner: Repository owner
            repo: Repository name
            event_type: Event type for the dispatch
            client_payload: Optional payload data
            
        Returns:
            True if successful, False otherwise
        """
        try:
            url = f"{self.base_url}/repos/{owner}/{repo}/dispatches"
            data = {
                'event_type': event_type,
                'client_payload': client_payload or {}
            }
            
            response = requests.post(url, headers=self.headers, json=data)
            response.raise_for_status()
            
            logger.info(f"Created repository dispatch: {event_type}")
            return True
            
        except requests.RequestException as e:
            logger.error(f"Failed to create repository dispatch: {e}")
            return False
    
    def get_pull_requests(self, owner: str, repo: str, state: str = 'all', 
                         base: Optional[str] = None) -> List[Dict]:
        """
        Get pull requests for a repository
        
        Args:
            owner: Repository owner
            repo: Repository name
            state: PR state (open, closed, all)
            base: Base branch to filter PRs
            
        Returns:
            List of pull request dictionaries
        """
        try:
            url = f"{self.base_url}/repos/{owner}/{repo}/pulls"
            params = {
                'state': state,
                'per_page': 100
            }
            
            if base:
                params['base'] = base
            
            response = requests.get(url, headers=self.headers, params=params)
            response.raise_for_status()
            
            pulls = response.json()
            return [
                {
                    'number': pr['number'],
                    'title': pr['title'],
                    'state': pr['state'],
                    'created_at': pr['created_at'],
                    'updated_at': pr['updated_at'],
                    'merged_at': pr.get('merged_at'),
                    'author': pr['user']['login'],
                    'url': pr['html_url']
                }
                for pr in pulls
            ]
            
        except requests.RequestException as e:
            logger.error(f"Failed to get pull requests: {e}")
            return []
    
    def check_rate_limit(self) -> Dict:
        """
        Check GitHub API rate limit status
        
        Returns:
            Dictionary with rate limit information
        """
        try:
            url = f"{self.base_url}/rate_limit"
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            
            rate_limit = response.json()
            return {
                'limit': rate_limit['rate']['limit'],
                'remaining': rate_limit['rate']['remaining'],
                'reset': rate_limit['rate']['reset'],
                'reset_time': datetime.fromtimestamp(rate_limit['rate']['reset'])
            }
            
        except requests.RequestException as e:
            logger.error(f"Failed to check rate limit: {e}")
            return {'limit': 0, 'remaining': 0, 'reset': 0}
