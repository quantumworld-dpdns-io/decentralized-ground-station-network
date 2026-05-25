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
  uptime?: number;
  type?: string;
}

interface StationMapProps {
  stations: StationLocation[];
  center?: [number, number];
  zoom?: number;
  height?: number;
  onStationClick?: (id: string) => void;
  selectedId?: string | null;
}

const statusColors: Record<string, string> = {
  online: '#22c55e',
  offline: '#ef4444',
  maintenance: '#eab308',
  error: '#ef4444',
};

export function InteractiveStationMap({
  stations,
  center = [20, 0],
  zoom = 2,
  height = 400,
  onStationClick,
  selectedId,
}: StationMapProps) {
  const mapRef = useRef<L.Map | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const markersRef = useRef<L.Marker[]>([]);
  const initializedRef = useRef(false);

  useEffect(() => {
    if (initializedRef.current || !containerRef.current) return;
    initializedRef.current = true;

    const map = L.map(containerRef.current, {
      center,
      zoom,
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
      initializedRef.current = false;
    };
  }, [center, zoom]);

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
        .bindTooltip(
          `<div style="font-weight:600;margin-bottom:2px">${station.name}</div>
           <div style="font-size:11px;color:#94a3b8">${station.type || ''} · ${station.status}</div>
           ${station.uptime ? `<div style="font-size:11px;color:#94a3b8">Uptime: ${station.uptime}%</div>` : ''}`,
          {
            permanent: false,
            direction: 'top',
            className: 'leaflet-tooltip-custom',
          },
        );

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
        map.fitBounds(bounds, { padding: [50, 50], maxZoom: 10 });
      }
    }
  }, [stations, selectedId, onStationClick]);

  return (
    <div className="glass rounded-xl overflow-hidden">
      <div ref={containerRef} style={{ width: '100%', height }} />
    </div>
  );
}
