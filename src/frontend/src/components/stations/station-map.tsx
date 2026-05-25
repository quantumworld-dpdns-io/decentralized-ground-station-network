'use client';

import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

interface StationLocation {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  status: 'online' | 'offline' | 'maintenance' | 'error';
}

interface StationMapProps {
  stations: StationLocation[];
  selectedId?: string | null;
  onStationClick?: (id: string) => void;
  height?: number;
}

const statusColors: Record<string, string> = {
  online: '#22c55e',
  offline: '#ef4444',
  maintenance: '#eab308',
  error: '#ef4444',
};

export function StationMap({
  stations,
  selectedId,
  onStationClick,
  height = 400,
}: StationMapProps) {
  const mapRef = useRef<L.Map | null>(null);
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const markersRef = useRef<L.Marker[]>([]);

  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    const map = L.map(mapContainerRef.current, {
      center: [20, 0],
      zoom: 2,
      zoomControl: true,
      scrollWheelZoom: true,
    });

    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      subdomains: 'abcd',
      maxZoom: 19,
    }).addTo(map);

    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    markersRef.current.forEach((marker) => marker.remove());
    markersRef.current = [];

    stations.forEach((station) => {
      const color = statusColors[station.status] || '#64748b';
      const isSelected = station.id === selectedId;

      const icon = L.divIcon({
        className: 'custom-marker',
        html: `
          <div style="
            width: ${isSelected ? '18px' : '12px'};
            height: ${isSelected ? '18px' : '12px'};
            background: ${color};
            border: 2px solid white;
            border-radius: 50%;
            box-shadow: 0 0 ${isSelected ? '12px' : '4px'} ${color};
            transition: all 0.2s;
          "/>
        `,
        iconSize: [isSelected ? 18 : 12, isSelected ? 18 : 12],
        iconAnchor: [isSelected ? 9 : 6, isSelected ? 9 : 6],
      });

      const marker = L.marker([station.latitude, station.longitude], { icon })
        .addTo(map)
        .bindTooltip(station.name, {
          permanent: false,
          direction: 'top',
          className: 'leaflet-tooltip-custom',
        });

      if (onStationClick) {
        marker.on('click', () => onStationClick(station.id));
      }

      markersRef.current.push(marker);
    });

    if (stations.length > 0) {
      const bounds = L.latLngBounds(
        stations.map((s) => [s.latitude, s.longitude]),
      );
      if (bounds.isValid()) {
        map.fitBounds(bounds, { padding: [50, 50] });
      }
    }
  }, [stations, selectedId, onStationClick]);

  return (
    <div className="glass rounded-xl overflow-hidden">
      <div ref={mapContainerRef} style={{ width: '100%', height }} />
    </div>
  );
}
