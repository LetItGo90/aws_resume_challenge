async function updateVisitorCount() {
    try {
        const response = await fetch('https://j5m7sjp9g5.execute-api.us-east-1.amazonaws.com/visitor');
        const data = await response.json();
        document.getElementById('visitor-count').textContent = data.count;
    } catch (error) {
        console.error('Error fetching visitor count:', error);
        document.getElementById('visitor-count').textContent = 'Error';
    }
}

window.onload = updateVisitorCount;